defmodule Exzm.EncrustedNif do
  use Rustler, otp_app: :exzm, crate: "encrusted_nif"

  def primer() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def detect_zmachine_input_type(_story, _save, _seed?, _seed_a, _seed_b, _seed_c, _seed_d) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_line_to_zmachine(_story, _save, _input, _seed?, _seed_a, _seed_b, _seed_c, _seed_d) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_char_to_zmachine(_story, _save, _input, _seed?, _seed_a, _seed_b, _seed_c, _seed_d) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

defmodule Exzm do
  alias Exzm.EncrustedNif

  # Suppress incorrect Dialyzer warnings due to NIF calls:
  @dialyzer {:no_return, send_zmachine_inputs: 4}
  @dialyzer {:no_return, send_zmachine_inputs_with_diagnostics: 4}

  # Parameters
  # ----------
  # story                    | non-empty binary
  # save                     | non-empty binary
  # "" <> input                   | string (may be blank)
  # [first_input | rest_inputs]   | non-empty list of strings
  # opts \\ []                    | optional keyword list of options
  #    L seed                     | random seed for deterministic story behavior
  #    L step_through_blank: true | auto-step through steps in story with no output
  #    L diagnostics: true        | return diagnostic info map as 3rd tuple value

  # Results
  # -------
  # {save: binary, output: str, seed: {int, int, int, int} }
  # {save: binary, output: str, seed, diagostics: %{nif_duration_ms: int} }

  # Public API
  # ----------
  # new_game/1 [story] -> {save, output, seed}
  # new_game/3 [story, input] -> {save, output, seed}
  # new_game/3 [story, inputs] -> {save, output, seed}
  # new_game/3 [story, input, opts] -> {save, output, seed, diagnostics}
  # new_game/3 [story, inputs, opts] -> {save, output, seed, diagnostics}
  # continue/4 [story, save, input] -> {save, output, seed}
  # continue/4 [story, save, inputs] -> {save, output, seed}
  # continue/4 [story, save, input, opts] -> {save, output, seed, diagnostics}
  # continue/4 [story, save, inputs, opts] -> {save, output, seed, diagnostics}

  # new_game/1 [story: binary]
  def new_game(story), do: new_game(story, "")

  # new_game/3: set default for opts:
  def new_game(story, input, opts \\ [])

  # new_game/3 [story: binary, input: string, opts?]
  def new_game(story, "" <> input, opts)
      when is_binary(story) and byte_size(story) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {step_through_blank?, opts} = Keyword.pop(opts, :step_through_blank, false)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    {save, output, seed, diagnostics} =
      if diagnostics? do
        send_zmachine_input_with_diagnostics(story, <<>>, input, seed)
      else
        {save, output, seed} =
          send_zmachine_input(story, <<>>, input, seed)

        {save, output, seed, nil}
      end

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if step_through_blank? and String.length(output) == 0 do
      continue(story, save, " ",
        seed: seed,
        step_through_blank: step_through_blank?,
        diagnostics: diagnostics?
      )
    else
      if diagnostics? do
        {save, output, seed, diagnostics}
      else
        {save, output, seed}
      end
    end
  end

  # new_game/3 [story: binary, inputs: string[], opts?]
  def new_game(story, [first_input | rest_inputs], opts)
      when is_binary(story) and byte_size(story) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    inputs = [first_input | rest_inputs]

    if diagnostics? do
      send_zmachine_inputs_with_diagnostics(story, <<>>, inputs, seed)
    else
      send_zmachine_inputs(story, <<>>, inputs, seed)
    end
  end

  # continue/4: set default for opts:
  def continue(story, save, input, opts \\ [])

  # continue/4 [story: binary, save: binary, input: string, opts?]
  def continue(story, save, "" <> input, opts)
      when is_binary(story) and byte_size(story) > 0 and
             is_binary(save) and byte_size(save) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {step_through_blank?, opts} = Keyword.pop(opts, :step_through_blank, false)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    {save, output, seed, diagnostics} =
      if diagnostics? do
        send_zmachine_input_with_diagnostics(story, save, input, seed)
      else
        {save, output, seed} =
          send_zmachine_input(story, save, input, seed)

        {save, output, seed, nil}
      end

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if step_through_blank? and String.length(output) == 0 do
      continue(story, save, " ",
        seed: seed,
        step_through_blank: step_through_blank?,
        diagnostics: diagnostics?
      )
    else
      if diagnostics? do
        {save, output, seed, diagnostics}
      else
        {save, output, seed}
      end
    end
  end

  # continue/4 [story: binary, save: binary, inputs: string[], opts?]
  def continue(story, save, [first_input | rest_inputs], opts)
      when is_binary(story) and byte_size(story) > 0 and
             is_binary(save) and byte_size(save) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    inputs = [first_input | rest_inputs]

    if diagnostics? do
      send_zmachine_inputs_with_diagnostics(story, save, inputs, seed)
    else
      send_zmachine_inputs(story, save, inputs, seed)
    end
  end

  # Private
  # -------

  defp format_output("" <> text) do
    # Trim whitespace and remove trailing prompt character from output text:
    text |> String.trim() |> String.trim_trailing(">") |> String.trim_trailing()
  end

  defp send_zmachine_input(story, save, input, seed) do
    {save, output, seed} =
      call_zmachine_nifs(story, save, input, seed)

    output = format_output(output)

    {save, output, seed}
  end

  defp send_zmachine_inputs(story, save, inputs, seed) do
    [first_input | rest_inputs] = inputs

    {save, first_output, seed} =
      call_zmachine_nifs(story, save, first_input, seed)

    {save, rest_output, seed} =
      send_zmachine_inputs(story, save, rest_inputs, seed)

    output = format_output(first_output <> rest_output)

    {save, output, seed}
  end

  defp send_zmachine_input_with_diagnostics(story, save, input, seed) do
    {save, output, seed, diagnostics} =
      call_zmachine_nifs_with_diagnostics(story, save, input, seed)

    output = format_output(output)

    {save, output, seed, diagnostics}
  end

  defp send_zmachine_inputs_with_diagnostics(story, save, inputs, seed) do
    [first_input | rest_inputs] = inputs

    {save, first_output, seed, first_diagnostics} =
      call_zmachine_nifs_with_diagnostics(story, save, first_input, seed)

    {save, rest_output, seed, rest_diagnostics} =
      send_zmachine_inputs_with_diagnostics(story, save, rest_inputs, seed)

    output = format_output(first_output <> rest_output)

    diagnostics = %{
      primer_nif_ms: first_diagnostics.primer_nif_ms + rest_diagnostics.primer_nif_ms,
      send_input_nif_ms:
        first_diagnostics.send_line_nif_ms +
          rest_diagnostics.send_line_nif_ms,
      send_char_nif_ms:
        first_diagnostics.send_char_nif_ms +
          rest_diagnostics.send_char_nif_ms
    }

    {save, output, seed, diagnostics}
  end

  defp prepare_seed_args({seed_a, seed_b, seed_c, seed_d})
       when is_integer(seed_a) and is_integer(seed_b) and is_integer(seed_c) and
              is_integer(seed_d) do
    seed? = true
    {seed?, seed_a, seed_b, seed_c, seed_d}
  end

  defp prepare_seed_args(nil) do
    seed? = false
    {seed?, 0, 0, 0, 0}
  end

  defp call_zmachine_nifs(
         story,
         save,
         input,
         seed
       ) do
    {seed?, seed_a, seed_b, seed_c, seed_d} = prepare_seed_args(seed)

    EncrustedNif.primer()

    {step, seed_a, seed_b, seed_c, seed_d} =
      apply(
        &EncrustedNif.detect_zmachine_input_type/7,
        [story, save, seed?, seed_a, seed_b, seed_c, seed_d]
      )

    {save, output, seed_a, seed_b, seed_c, seed_d} =
      case step do
        "ReadLine" ->
          apply(
            &EncrustedNif.send_line_to_zmachine/8,
            [story, save, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        "ReadChar" ->
          apply(
            &EncrustedNif.send_char_to_zmachine/8,
            [story, save, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    seed = {seed_a, seed_b, seed_c, seed_d}

    {save, output, seed}
  end

  defp call_zmachine_nifs_with_diagnostics(
         story,
         save,
         input,
         seed
       ) do
    {seed?, seed_a, seed_b, seed_c, seed_d} = prepare_seed_args(seed)

    {prime_nif_microsec, {}} = :timer.tc(&EncrustedNif.primer/0, [])

    {detection_nif_microsec, {step, seed_a, seed_b, seed_c, seed_d}} =
      :timer.tc(
        &EncrustedNif.detect_zmachine_input_type/7,
        [story, save, seed?, seed_a, seed_b, seed_c, seed_d]
      )

    {send_nif_microsec, {save, output, seed_a, seed_b, seed_c, seed_d}} =
      case step do
        "ReadLine" ->
          :timer.tc(
            &EncrustedNif.send_line_to_zmachine/8,
            [story, save, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        "ReadChar" ->
          :timer.tc(
            &EncrustedNif.send_char_to_zmachine/8,
            [story, save, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    diagnostics =
      case step do
        "ReadLine" ->
          %{
            primer_nif_ms: prime_nif_microsec / 1000,
            detection_nif_ms: detection_nif_microsec / 1000,
            send_line_nif_ms: send_nif_microsec / 1000,
            send_char_nif_ms: 0
          }

        "ReadChar" ->
          %{
            primer_nif_ms: prime_nif_microsec / 1000,
            detection_nif_ms: detection_nif_microsec / 1000,
            send_line_nif_ms: 0,
            send_char_nif_ms: send_nif_microsec / 1000
          }

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    seed = {seed_a, seed_b, seed_c, seed_d}

    {save, output, seed, diagnostics}
  end
end
