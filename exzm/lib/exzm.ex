defmodule Exzm.EncrustedNif do
  use Rustler, otp_app: :exzm, crate: "encrusted_nif"

  def generate_zmachine_random_seed() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def init_zmachine(_story, _save, _seed_a, _seed_b, _seed_c, _seed_d) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def step_zmachine(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_line_to_zmachine(_zmachine_resource_arc, _input) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_char_to_zmachine(_zmachine_resource_arc, _input) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def drain_zmachine_output(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def save_zmachine_state(_zmachine_resource_arc) do
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
      step_1_nif_ms: first_diagnostics.step_1_nif_ms + rest_diagnostics.step_1_nif_ms,
      step_2_nif_ms: first_diagnostics.step_2_nif_ms + rest_diagnostics.step_2_nif_ms,
      output_nif_ms: first_diagnostics.output_nif_ms + rest_diagnostics.output_nif_ms,
      save_nif_ms: first_diagnostics.save_nif_ms + rest_diagnostics.save_nif_ms,
      send_input_nif_ms:
        first_diagnostics.send_line_nif_ms +
          rest_diagnostics.send_line_nif_ms,
      send_char_nif_ms:
        first_diagnostics.send_char_nif_ms +
          rest_diagnostics.send_char_nif_ms
    }

    {save, output, seed, diagnostics}
  end

  defp call_zmachine_nifs(story, save, input, seed) do
    {seed_a, seed_b, seed_c, seed_d} =
      case seed do
        {seed_a, seed_b, seed_c, seed_d}
        when is_integer(seed_a) and is_integer(seed_b) and is_integer(seed_c) and
               is_integer(seed_d) ->
          {seed_a, seed_b, seed_c, seed_d}

        _ ->
          EncrustedNif.generate_zmachine_random_seed()
      end

    zmachine =
      apply(
        &EncrustedNif.init_zmachine/6,
        [story, save, seed_a, seed_b, seed_c, seed_d]
      )

    step = EncrustedNif.step_zmachine(zmachine)

    case step do
      "ReadLine" ->
        EncrustedNif.send_line_to_zmachine(zmachine, input)

      "ReadChar" ->
        EncrustedNif.send_char_to_zmachine(zmachine, input)

      unexpected ->
        raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
    end

    EncrustedNif.step_zmachine(zmachine)

    output = EncrustedNif.drain_zmachine_output(zmachine)
    save = EncrustedNif.save_zmachine_state(zmachine)

    # Note: Save NIF returns Vec[u8] directly for simplicity,
    # so we need to convert from list to Elixir binary here:
    save = :binary.list_to_bin(save)

    seed = {seed_a, seed_b, seed_c, seed_d}

    {save, output, seed}
  end

  defp call_zmachine_nifs_with_diagnostics(story, save, input, seed) do
    {seed_nif_microsec, {seed_a, seed_b, seed_c, seed_d}} =
      case seed do
        {seed_a, seed_b, seed_c, seed_d}
        when is_integer(seed_a) and is_integer(seed_b) and is_integer(seed_c) and
               is_integer(seed_d) ->
          {0, {seed_a, seed_b, seed_c, seed_d}}

        _ ->
          :timer.tc(&EncrustedNif.generate_zmachine_random_seed/0, [])
      end

    {init_nif_microsec, zmachine} =
      :timer.tc(
        &EncrustedNif.init_zmachine/6,
        [story, save, seed_a, seed_b, seed_c, seed_d]
      )

    {step_1_nif_microsec, step} =
      :timer.tc(&EncrustedNif.step_zmachine/1, [zmachine])

    {send_nif_microsec, {}} =
      case step do
        "ReadLine" ->
          :timer.tc(&EncrustedNif.send_line_to_zmachine/2, [zmachine, input])

        "ReadChar" ->
          :timer.tc(&EncrustedNif.send_char_to_zmachine/2, [zmachine, input])

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    {step_2_nif_microsec, _step} =
      :timer.tc(&EncrustedNif.step_zmachine/1, [zmachine])

    {output_nif_microsec, output} =
      :timer.tc(&EncrustedNif.drain_zmachine_output/1, [zmachine])

    {save_nif_microsec, save} =
      :timer.tc(&EncrustedNif.save_zmachine_state/1, [zmachine])

    # Note: Save NIF returns Vec[u8] directly for simplicity,
    # so we need to convert from list to Elixir binary here:
    save = :binary.list_to_bin(save)

    diagnostics = %{
      seed_nif_ms: seed_nif_microsec / 1000,
      init_nif_ms: init_nif_microsec / 1000,
      step_1_nif_ms: step_1_nif_microsec / 1000,
      send_line_nif_ms: 0,
      send_char_nif_ms: 0,
      step_2_nif_ms: step_2_nif_microsec / 1000,
      output_nif_ms: output_nif_microsec / 1000,
      save_nif_ms: save_nif_microsec / 1000
    }

    diagnostics =
      case step do
        "ReadLine" ->
          %{diagnostics | send_line_nif_ms: send_nif_microsec / 1000}

        "ReadChar" ->
          %{diagnostics | send_char_nif_ms: send_nif_microsec / 1000}

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    seed = {seed_a, seed_b, seed_c, seed_d}

    {save, output, seed, diagnostics}
  end
end
