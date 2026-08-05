defmodule Exzm.EncrustedNif do
  use Rustler, otp_app: :exzm, crate: "encrusted_nif"

  def prime_zmachine(
        _story_data,
        _state_data,
        _seed?,
        _seed_a,
        _seed_b,
        _seed_c,
        _seed_d
      ) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_line_to_zmachine(
        _story_data,
        _state_data,
        _input,
        _seed?,
        _seed_a,
        _seed_b,
        _seed_c,
        _seed_d
      ) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_char_to_zmachine(
        _story_data,
        _state_data,
        _input,
        _seed?,
        _seed_a,
        _seed_b,
        _seed_c,
        _seed_d
      ) do
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
  # story_data                    | non-empty binary
  # save_data                     | non-empty binary
  # "" <> input                   | string (may be blank)
  # [first_input | rest_inputs]   | non-empty list of strings
  # opts \\ []                    | optional keyword list of options
  #    L seed                     | random seed for deterministic story behavior
  #    L step_through_blank: true | auto-step through steps in story with no output
  #    L diagnostics: true        | return diagnostic info map as 3rd tuple value

  # Results
  # -------
  # {save_data: binary, output: str, seed: {int, int, int, int} }
  # {save_data: binary, output: str, seed, diagostics: %{nif_duration_ms: int} }

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

  # new_game/1 [story_data: binary]
  def new_game(story_data), do: new_game(story_data, "")

  # new_game/3: set default for opts:
  def new_game(story_data, input, opts \\ [])

  # new_game/3 [story_data: binary, input: string, opts?]
  def new_game(story_data, "" <> input, opts)
      when is_binary(story_data) and byte_size(story_data) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {step_through_blank?, opts} = Keyword.pop(opts, :step_through_blank, false)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    {save_data, output, seed, diagnostics} =
      if diagnostics? do
        send_zmachine_input_with_diagnostics(story_data, <<>>, input, seed)
      else
        {save_data, output, seed} =
          send_zmachine_input(story_data, <<>>, input, seed)

        {save_data, output, seed, nil}
      end

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if step_through_blank? and String.length(output) == 0 do
      continue(story_data, save_data, " ",
        seed: seed,
        step_through_blank: step_through_blank?,
        diagnostics: diagnostics?
      )
    else
      if diagnostics? do
        {save_data, output, seed, diagnostics}
      else
        {save_data, output, seed}
      end
    end
  end

  # new_game/3 [story_data: binary, inputs: string[], opts?]
  def new_game(story_data, [first_input | rest_inputs], opts)
      when is_binary(story_data) and byte_size(story_data) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    inputs = [first_input | rest_inputs]

    if diagnostics? do
      send_zmachine_inputs_with_diagnostics(story_data, <<>>, inputs, seed)
    else
      send_zmachine_inputs(story_data, <<>>, inputs, seed)
    end
  end

  # continue/4: set default for opts:
  def continue(story_data, save_data, input, opts \\ [])

  # continue/4 [story_data: binary, save_data: binary, input: string, opts?]
  def continue(story_data, save_data, "" <> input, opts)
      when is_binary(story_data) and byte_size(story_data) > 0 and
             is_binary(save_data) and byte_size(save_data) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {step_through_blank?, opts} = Keyword.pop(opts, :step_through_blank, false)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    {save_data, output, seed, diagnostics} =
      if diagnostics? do
        send_zmachine_input_with_diagnostics(story_data, save_data, input, seed)
      else
        {save_data, output, seed} =
          send_zmachine_input(story_data, save_data, input, seed)

        {save_data, output, seed, nil}
      end

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if step_through_blank? and String.length(output) == 0 do
      continue(story_data, save_data, " ",
        seed: seed,
        step_through_blank: step_through_blank?,
        diagnostics: diagnostics?
      )
    else
      if diagnostics? do
        {save_data, output, seed, diagnostics}
      else
        {save_data, output, seed}
      end
    end
  end

  # continue/4 [story_data: binary, save_data: binary, inputs: string[], opts?]
  def continue(story_data, save_data, [first_input | rest_inputs], opts)
      when is_binary(story_data) and byte_size(story_data) > 0 and
             is_binary(save_data) and byte_size(save_data) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    inputs = [first_input | rest_inputs]

    if diagnostics? do
      send_zmachine_inputs_with_diagnostics(story_data, save_data, inputs, seed)
    else
      send_zmachine_inputs(story_data, save_data, inputs, seed)
    end
  end

  # Private
  # -------

  defp format_output("" <> text) do
    # Trim whitespace and remove trailing prompt character from output text:
    text |> String.trim() |> String.trim_trailing(">") |> String.trim_trailing()
  end

  defp send_zmachine_input(story_data, save_data, input, seed) do
    {save_data, output, seed} =
      prime_zmachine_then_send(story_data, save_data, input, seed)

    output = format_output(output)

    {save_data, output, seed}
  end

  defp send_zmachine_inputs(story_data, save_data, inputs, seed) do
    [first_input | rest_inputs] = inputs

    {save_data, first_output, seed} =
      prime_zmachine_then_send(story_data, save_data, first_input, seed)

    {save_data, rest_output, seed} =
      send_zmachine_inputs(story_data, save_data, rest_inputs, seed)

    output = format_output(first_output <> rest_output)

    {save_data, output, seed}
  end

  defp send_zmachine_input_with_diagnostics(story_data, save_data, input, seed) do
    {save_data, output, seed, diagnostics} =
      prime_zmachine_then_send_with_diagnostics(story_data, save_data, input, seed)

    output = format_output(output)

    {save_data, output, seed, diagnostics}
  end

  defp send_zmachine_inputs_with_diagnostics(story_data, save_data, inputs, seed) do
    [first_input | rest_inputs] = inputs

    {save_data, first_output, seed, first_diagnostics} =
      prime_zmachine_then_send_with_diagnostics(story_data, save_data, first_input, seed)

    {save_data, rest_output, seed, rest_diagnostics} =
      send_zmachine_inputs_with_diagnostics(story_data, save_data, rest_inputs, seed)

    output = format_output(first_output <> rest_output)

    diagnostics = %{
      prime_zmachine_nif_ms:
        first_diagnostics.prime_zmachine_nif_ms + rest_diagnostics.prime_zmachine_nif_ms,
      send_input_to_zmachine_nif_ms:
        first_diagnostics.send_line_to_zmachine_nif_ms +
          rest_diagnostics.send_line_to_zmachine_nif_ms,
      send_char_to_zmachine_nif_ms:
        first_diagnostics.send_char_to_zmachine_nif_ms +
          rest_diagnostics.send_char_to_zmachine_nif_ms
    }

    {save_data, output, seed, diagnostics}
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

  defp prime_zmachine_then_send(
         story_data,
         save_data,
         input,
         seed
       ) do
    {seed?, seed_a, seed_b, seed_c, seed_d} = prepare_seed_args(seed)

    {save_data, prime_output, state, seed_a, seed_b, seed_c, seed_d} =
      apply(
        &EncrustedNif.prime_zmachine/7,
        [story_data, save_data, seed?, seed_a, seed_b, seed_c, seed_d]
      )

    {save_data, send_output, seed_a, seed_b, seed_c, seed_d} =
      case state do
        "read_line" ->
          apply(
            &EncrustedNif.send_line_to_zmachine/8,
            [story_data, save_data, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        "read_char" ->
          apply(
            &EncrustedNif.send_char_to_zmachine/8,
            [story_data, save_data, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine State (#{unexpected})")
      end

    output = prime_output <> send_output
    seed = {seed_a, seed_b, seed_c, seed_d}

    {save_data, output, seed}
  end

  defp prime_zmachine_then_send_with_diagnostics(
         story_data,
         save_data,
         input,
         seed
       ) do
    {seed?, seed_a, seed_b, seed_c, seed_d} = prepare_seed_args(seed)

    {prime_nif_microsec, {save_data, prime_output, state, seed_a, seed_b, seed_c, seed_d}} =
      :timer.tc(
        &EncrustedNif.prime_zmachine/7,
        [story_data, save_data, seed?, seed_a, seed_b, seed_c, seed_d]
      )

    {send_nif_microsec, {save_data, send_output, seed_a, seed_b, seed_c, seed_d}} =
      case state do
        "read_line" ->
          :timer.tc(
            &EncrustedNif.send_line_to_zmachine/8,
            [story_data, save_data, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        "read_char" ->
          :timer.tc(
            &EncrustedNif.send_char_to_zmachine/8,
            [story_data, save_data, input, seed?, seed_a, seed_b, seed_c, seed_d]
          )

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine State (#{unexpected})")
      end

    diagnostics =
      case state do
        "read_line" ->
          %{
            prime_zmachine_nif_ms: prime_nif_microsec / 1000,
            send_line_to_zmachine_nif_ms: send_nif_microsec / 1000,
            send_char_to_zmachine_nif_ms: 0
          }

        "read_char" ->
          %{
            prime_zmachine_nif_ms: prime_nif_microsec / 1000,
            send_line_to_zmachine_nif_ms: 0,
            send_char_to_zmachine_nif_ms: send_nif_microsec / 1000
          }

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine State (#{unexpected})")
      end

    output = prime_output <> send_output
    seed = {seed_a, seed_b, seed_c, seed_d}

    {save_data, output, seed, diagnostics}
  end
end
