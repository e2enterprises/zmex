defmodule Exzm.EncrustedNif do
  use Rustler, otp_app: :exzm, crate: "encrusted_nif"

  def advance_zmachine(_story_data, _state_data, _input_string) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

defmodule Exzm do
  alias Exzm.EncrustedNif

  # Suppress incorrect Dialyzer warnings due to NIF calls:
  @dialyzer {:no_return, send_zmachine_inputs: 3}
  @dialyzer {:no_return, send_zmachine_inputs_with_diagnostics: 3}

  # Parameters
  # ----------
  # story_data                  | non-empty binary
  # save_data                   | non-empty binary
  # "" <> input                 | string (may be blank)
  # [first_input | rest_inputs] | non-empty list of strings
  # opts \\ []                  | optional keyword list of options
  #    L diagnostics: true      | return diagnostic info map as 3rd tuple value

  # Results
  # -------
  # {save_data: binary, output: string}
  # {save_data: binary, output: string, diagostics: %{nif_duration_ms: integer} }

  # Public API
  # ----------
  # new_game/1 [story_data] -> {save_data, output}
  # new_game/3 [story_data, input] -> {save_data, output}
  # new_game/3 [story_data, inputs] -> {save_data, output}
  # new_game/3 [story_data, input, diagnostics] -> {save_data, output, diagnostics}
  # new_game/3 [story_data, inputs, diagnostics] -> {save_data, output, diagnostics}
  # continue/4 [story_data, save_data, input] -> {save_data, output}
  # continue/4 [story_data, save_data, inputs] -> {save_data, output}
  # continue/4 [story_data, save_data, input, diag.] -> {save_data, output, diag.}
  # continue/4 [story_data, save_data, inputs, diag.] -> {save_data, output, diag.}

  # new_game/1 [story_data: binary]
  def new_game(story_data), do: new_game(story_data, "")

  # new_game/3: set default for opts:
  def new_game(story_data, input, opts \\ [])

  # new_game/3 [story_data: binary, input: string, opts?]
  def new_game(story_data, "" <> input, opts)
      when is_binary(story_data) and byte_size(story_data) > 0 do
    include_diagnostics = Keyword.get(opts, :diagnostics)

    {save_data, output, diagnostics} =
      if include_diagnostics do
        send_zmachine_input_with_diagnostics(story_data, <<>>, input)
      else
        {save_data, output} =
          send_zmachine_input(story_data, <<>>, input)

        {save_data, output, nil}
      end

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if !!Keyword.get(opts, :step_through_blank) and String.length(output) == 0 do
      continue(story_data, save_data, " ", opts)
    else
      if include_diagnostics do
        {save_data, output, diagnostics}
      else
        {save_data, output}
      end
    end
  end

  # new_game/3 [story_data: binary, inputs: string[], opts?]
  def new_game(story_data, [first_input | rest_inputs], opts)
      when is_binary(story_data) and byte_size(story_data) > 0 do
    inputs = [first_input | rest_inputs]

    if Keyword.get(opts, :diagnostics) do
      send_zmachine_inputs_with_diagnostics(story_data, <<>>, inputs)
    else
      send_zmachine_inputs(story_data, <<>>, inputs)
    end
  end

  # continue/4: set default for opts:
  def continue(story_data, save_data, input, opts \\ [])

  # continue/4 [story_data: binary, save_data: binary, input: string, opts?]
  def continue(story_data, save_data, "" <> input, opts)
      when is_binary(story_data) and byte_size(story_data) > 0 and
             is_binary(save_data) and byte_size(save_data) > 0 do
    include_diagnostics = Keyword.get(opts, :diagnostics)

    {save_data, output, diagnostics} =
      if include_diagnostics do
        send_zmachine_input_with_diagnostics(story_data, save_data, input)
      else
        {save_data, output} =
          send_zmachine_input(story_data, save_data, input)

        {save_data, output, nil}
      end

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if !!Keyword.get(opts, :step_through_blank) and String.length(output) == 0 do
      continue(story_data, save_data, " ", opts)
    else
      if include_diagnostics do
        {save_data, output, diagnostics}
      else
        {save_data, output}
      end
    end
  end

  # continue/4 [story_data: binary, save_data: binary, inputs: string[], opts?]
  def continue(story_data, save_data, [first_input | rest_inputs], opts)
      when is_binary(story_data) and byte_size(story_data) > 0 and
             is_binary(save_data) and byte_size(save_data) > 0 do
    inputs = [first_input | rest_inputs]

    if Keyword.get(opts, :diagnostics) do
      send_zmachine_inputs_with_diagnostics(story_data, save_data, inputs)
    else
      send_zmachine_inputs(story_data, save_data, inputs)
    end
  end

  # Private
  # -------

  defp format_output("" <> text) do
    # Trim whitespace and remove trailing prompt character from output text:
    text |> String.trim() |> String.trim_trailing(">") |> String.trim_trailing()
  end

  defp send_zmachine_input(story_data, save_data, input) do
    {save_data, output} =
      EncrustedNif.advance_zmachine(story_data, save_data, input)

    output = format_output(output)

    {save_data, output}
  end

  @dialyzer {:no_return, send_zmachine_inputs: 3}
  defp send_zmachine_inputs(story_data, save_data, inputs) do
    [first_input | rest_inputs] = inputs

    {new_save_data, first_output} =
      EncrustedNif.advance_zmachine(story_data, save_data, first_input)

    {new_save_data, rest_output} =
      send_zmachine_inputs(story_data, new_save_data, rest_inputs)

    output = format_output(first_output <> rest_output)

    {new_save_data, output}
  end

  defp send_zmachine_input_with_diagnostics(story_data, save_data, input) do
    {nif_duration, {new_save_data, output}} =
      :timer.tc(
        &EncrustedNif.advance_zmachine/3,
        [story_data, save_data, input]
      )

    output = format_output(output)
    diagnostics = %{nif_duration_ms: nif_duration / 1000}

    {new_save_data, output, diagnostics}
  end

  defp send_zmachine_inputs_with_diagnostics(story_data, save_data, inputs) do
    [first_input | rest_inputs] = inputs

    {first_nif_duration, {new_save_data, first_output}} =
      :timer.tc(
        &EncrustedNif.advance_zmachine/3,
        [story_data, save_data, first_input]
      )

    {new_save_data, rest_output, %{nif_duration_ms: rest_nif_duration_ms}} =
      send_zmachine_inputs_with_diagnostics(story_data, new_save_data, rest_inputs)

    output = format_output(first_output <> rest_output)
    diagnostics = %{nif_duration_ms: first_nif_duration / 1000 + rest_nif_duration_ms}

    {new_save_data, output, diagnostics}
  end
end
