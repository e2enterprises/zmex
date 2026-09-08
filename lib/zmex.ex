defmodule Zmex.EncrustedNif do
  use Rustler, otp_app: :zmex, crate: "encrusted_nif"

  def generate_zmachine_random_seed() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def init_zmachine(_story, _save, _seed_a, _seed_b, _seed_c, _seed_d) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def step_zmachine(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def compute_zmachine_unicode_table(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_line_to_zmachine(_zmachine_resource_arc, _input) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_char_to_zmachine(_zmachine_resource_arc, _input, _unicode_table) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def drain_zmachine_output(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def save_zmachine_state(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def generate_zmachine_random_seed_dirty_cpu() do
    :erlang.nif_error(:nif_not_loaded)
  end

  def init_zmachine_dirty_cpu(_story, _save, _seed_a, _seed_b, _seed_c, _seed_d) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def step_zmachine_dirty_cpu(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def compute_zmachine_unicode_table_dirty_cpu(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_line_to_zmachine_dirty_cpu(_zmachine_resource_arc, _input) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def send_char_to_zmachine_dirty_cpu(_zmachine_resource_arc, _input, _unicode_table) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def drain_zmachine_output_dirty_cpu(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def save_zmachine_state_dirty_cpu(_zmachine_resource_arc) do
    :erlang.nif_error(:nif_not_loaded)
  end
end

defmodule Zmex do
  alias Zmex.EncrustedNif
  import DryDoc

  @moduledoc doc_from_readme()

  # Suppress incorrect Dialyzer warnings due to NIF calls:
  @dialyzer {:no_return, send_zmachine_inputs: 6}
  @dialyzer {:no_return, send_zmachine_inputs_with_diagnostics: 6}

  # Parameters
  # ----------
  # story · · · · · · · · · · · · · non-empty binary
  # save  · · · · · · · · · · · · · non-empty binary
  # "" <> input · · · · · · · · · · string (may be blank)
  # [first_input | rest_inputs] · · non-empty list of strings
  # opts \\ []  · · · · · · · · · · optional keyword list of options
  #    L seed: nil  · · · · · · · · random seed for deterministic story behavior
  #    L step_through_blank: true · auto-step through steps in story with no output
  #    L diagnostics: true  · · · · return diagnostic info map as 3rd tuple value
  #    L dirty_nifs: [] · · · · · · list of atoms corresponding with NIF functions
  #                               · to be marked with schedule="DirtyCpu" for Rustler
  # Return Tuples
  # -------------
  # diagnostics: false ->
  #   {save: binary, output: str, seed: {i32, i32, i32, i32} }
  # diagnostics: true ->
  #   {save: binary, output: str, seed: {i32 x 4}, diagostics: %{nif_duration: i32} }
  # Note: NIF diagnostic timing durations are always returned in milliseconds.
  #
  # Public API
  # ----------
  # new_game/1 [story] -> {save, output, seed}
  # new_game/2 [story, input] -> {save, output, seed}
  # new_game/2 [story, inputs] -> {save, output, seed}
  # new_game/3 [story, input, opts] -> {save, output, seed, diagnostics}
  # new_game/3 [story, inputs, opts] -> {save, output, seed, diagnostics}
  # continue/3 [story, save, input] -> {save, output, seed}
  # continue/3 [story, save, inputs] -> {save, output, seed}
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
    {dirty_nifs, opts} = Keyword.pop(opts, :dirty_nifs, [])
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    {save, output, seed, diagnostics} =
      if diagnostics? do
        send_zmachine_input_with_diagnostics(
          story,
          <<>>,
          input,
          seed,
          step_through_blank?,
          dirty_nifs
        )
      else
        {save, output, seed} =
          send_zmachine_input(story, <<>>, input, seed, step_through_blank?, dirty_nifs)

        {save, output, seed, nil}
      end

    if diagnostics? do
      {save, output, seed, diagnostics}
    else
      {save, output, seed}
    end
  end

  # new_game/3 [story: binary, inputs: string[], opts?]
  def new_game(story, [first_input | rest_inputs], opts)
      when is_binary(story) and byte_size(story) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {step_through_blank?, opts} = Keyword.pop(opts, :step_through_blank, false)
    {dirty_nifs, opts} = Keyword.pop(opts, :dirty_nifs, [])
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    inputs = [first_input | rest_inputs]

    if diagnostics? do
      send_zmachine_inputs_with_diagnostics(
        story,
        <<>>,
        inputs,
        seed,
        step_through_blank?,
        dirty_nifs
      )
    else
      send_zmachine_inputs(story, <<>>, inputs, seed, step_through_blank?, dirty_nifs)
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
    {dirty_nifs, opts} = Keyword.pop(opts, :dirty_nifs, [])
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    {save, output, seed, diagnostics} =
      if diagnostics? do
        send_zmachine_input_with_diagnostics(
          story,
          save,
          input,
          seed,
          step_through_blank?,
          dirty_nifs
        )
      else
        {save, output, seed} =
          send_zmachine_input(story, save, input, seed, step_through_blank?, dirty_nifs)

        {save, output, seed, nil}
      end

    if diagnostics? do
      {save, output, seed, diagnostics}
    else
      {save, output, seed}
    end
  end

  # continue/4 [story: binary, save: binary, inputs: string[], opts?]
  def continue(story, save, [first_input | rest_inputs], opts)
      when is_binary(story) and byte_size(story) > 0 and
             is_binary(save) and byte_size(save) > 0 do
    {seed, opts} = Keyword.pop(opts, :seed, nil)
    {step_through_blank?, opts} = Keyword.pop(opts, :step_through_blank, false)
    {dirty_nifs, opts} = Keyword.pop(opts, :dirty_nifs, [])
    {diagnostics?, opts} = Keyword.pop(opts, :diagnostics, false)
    if !Enum.empty?(opts), do: raise(ArgumentError, "invalid opts #{inspect(opts)}")

    inputs = [first_input | rest_inputs]

    if diagnostics? do
      send_zmachine_inputs_with_diagnostics(
        story,
        save,
        inputs,
        seed,
        step_through_blank?,
        dirty_nifs
      )
    else
      send_zmachine_inputs(story, save, inputs, seed, step_through_blank?, dirty_nifs)
    end
  end

  # Private
  # -------

  defp format_output("" <> text) do
    # Trim whitespace and remove trailing prompt character from output text:
    text |> String.trim() |> String.trim_trailing(">") |> String.trim_trailing()
  end

  defp combine_diagnostics(first_diagnostics, rest_diagnostics) do
    cond do
      rest_diagnostics == nil ->
        first_diagnostics

      first_diagnostics == nil ->
        rest_diagnostics

      true ->
        for key <- Enum.uniq(Map.keys(first_diagnostics) ++ Map.keys(rest_diagnostics)),
            into: %{} do
          {key, Map.fetch!(first_diagnostics, key) ++ Map.fetch!(rest_diagnostics, key)}
          # Force diagnostics maps to match with uniq and fetch!; will error out otherwise.
          # Performance is not a concern, diagnostics map size will be small.
        end
    end
  end

  defp send_zmachine_input(story, save, input, seed, step_through_blank?, dirty_nifs) do
    {save, output, seed} =
      call_zmachine_nifs(story, save, input, seed, dirty_nifs)

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if step_through_blank? and String.length(output) == 0 do
      call_zmachine_nifs(story, save, " ", seed, dirty_nifs)
    else
      {save, output, seed}
    end
  end

  defp send_zmachine_input_with_diagnostics(
         story,
         save,
         input,
         seed,
         step_through_blank?,
         dirty_nifs
       ) do
    {save, output, seed, diagnostics} =
      call_zmachine_nifs_with_diagnostics(story, save, input, seed, dirty_nifs)

    # If output is blank and :step_through_blank specified, take another ZVM step:
    if step_through_blank? and String.length(output) == 0 do
      {save, output, seed, blank_step_diagnostics} =
        call_zmachine_nifs_with_diagnostics(story, save, " ", seed, dirty_nifs)

      {save, output, seed, combine_diagnostics(diagnostics, blank_step_diagnostics)}
    else
      {save, output, seed, diagnostics}
    end
  end

  defp send_zmachine_inputs(
         story,
         save,
         inputs,
         seed,
         step_through_blank?,
         dirty_nifs,
         prior_output \\ ""
       ) do
    [first_input | rest_inputs] = inputs

    {save, output, seed} =
      call_zmachine_nifs(story, save, first_input, seed, dirty_nifs)

    # If output is blank and :step_through_blank specified, take another ZVM step:
    {save, output, seed} =
      if step_through_blank? and String.length(output) == 0 do
        call_zmachine_nifs(story, save, " ", seed, dirty_nifs)
      else
        {save, output, seed}
      end

    case rest_inputs do
      [] ->
        {save, prior_output <> output, seed}

      _ ->
        send_zmachine_inputs(
          story,
          save,
          rest_inputs,
          seed,
          step_through_blank?,
          dirty_nifs,
          prior_output <> output
          # Tail-call optimization: prior_output passed here
          # so this recursive call is the final expression.
        )
    end
  end

  defp send_zmachine_inputs_with_diagnostics(
         story,
         save,
         inputs,
         seed,
         step_through_blank?,
         dirty_nifs,
         prior_output \\ "",
         prior_diagnostics \\ nil
       ) do
    [first_input | rest_inputs] = inputs

    {save, output, seed, diagnostics} =
      call_zmachine_nifs_with_diagnostics(story, save, first_input, seed, dirty_nifs)

    # If output is blank and :step_through_blank specified, take another ZVM step:
    {save, output, seed, diagnostics} =
      if step_through_blank? and String.length(output) == 0 do
        {save, output, seed, blank_step_diagnostics} =
          call_zmachine_nifs_with_diagnostics(story, save, " ", seed, dirty_nifs)

        {save, output, seed, combine_diagnostics(diagnostics, blank_step_diagnostics)}
      else
        {save, output, seed, diagnostics}
      end

    case rest_inputs do
      [] ->
        {save, prior_output <> output, seed, combine_diagnostics(prior_diagnostics, diagnostics)}

      _ ->
        send_zmachine_inputs_with_diagnostics(
          story,
          save,
          rest_inputs,
          seed,
          step_through_blank?,
          dirty_nifs,
          prior_output <> output,
          combine_diagnostics(prior_diagnostics, diagnostics)
          # Tail-call optimization: prior_output and prior_diagnostics passed here
          # so this recursive call is the final expression.
        )
    end
  end

  defp call_nif(dirty_nifs, nif_atom, nif_func, dirty_nif_func, arguments) do
    if nif_atom in dirty_nifs do
      apply(dirty_nif_func, arguments)
    else
      apply(nif_func, arguments)
    end
  end

  defp call_zmachine_nifs(story, save, input, seed, dirty_nifs) do
    {seed_a, seed_b, seed_c, seed_d} =
      case seed do
        {seed_a, seed_b, seed_c, seed_d}
        when is_integer(seed_a) and is_integer(seed_b) and is_integer(seed_c) and
               is_integer(seed_d) ->
          {seed_a, seed_b, seed_c, seed_d}

        _ ->
          call_nif(
            dirty_nifs,
            :generate_zmachine_random_seed,
            &EncrustedNif.generate_zmachine_random_seed/0,
            &EncrustedNif.generate_zmachine_random_seed_dirty_cpu/0,
            []
          )
      end

    zmachine =
      call_nif(
        dirty_nifs,
        :init_zmachine,
        &EncrustedNif.init_zmachine/6,
        &EncrustedNif.init_zmachine_dirty_cpu/6,
        [story, save, seed_a, seed_b, seed_c, seed_d]
      )

    step =
      call_nif(
        dirty_nifs,
        :step_zmachine,
        &EncrustedNif.step_zmachine/1,
        &EncrustedNif.step_zmachine_dirty_cpu/1,
        [zmachine]
      )

    case step do
      "ReadLine" ->
        call_nif(
          dirty_nifs,
          :send_line_to_zmachine,
          &EncrustedNif.send_line_to_zmachine/2,
          &EncrustedNif.send_line_to_zmachine_dirty_cpu/2,
          [zmachine, input]
        )

      "ReadChar" ->
        unicode_table =
          call_nif(
            dirty_nifs,
            :compute_zmachine_unicode_table,
            &EncrustedNif.compute_zmachine_unicode_table/1,
            &EncrustedNif.compute_zmachine_unicode_table_dirty_cpu/1,
            [zmachine]
          )

        call_nif(
          dirty_nifs,
          :send_char_to_zmachine,
          &EncrustedNif.send_char_to_zmachine/3,
          &EncrustedNif.send_char_to_zmachine_dirty_cpu/3,
          [zmachine, input, unicode_table]
        )

      unexpected ->
        raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
    end

    call_nif(
      dirty_nifs,
      :step_zmachine,
      &EncrustedNif.step_zmachine/1,
      &EncrustedNif.step_zmachine_dirty_cpu/1,
      [zmachine]
    )

    output =
      call_nif(
        dirty_nifs,
        :drain_zmachine_output,
        &EncrustedNif.drain_zmachine_output/1,
        &EncrustedNif.drain_zmachine_output_dirty_cpu/1,
        [zmachine]
      )

    save =
      call_nif(
        dirty_nifs,
        :save_zmachine_state,
        &EncrustedNif.save_zmachine_state/1,
        &EncrustedNif.save_zmachine_state_dirty_cpu/1,
        [zmachine]
      )

    # Note: Save NIF returns Vec[u8] directly for simplicity,
    # so we need to convert from list to Elixir binary here:
    save = :binary.list_to_bin(save)

    seed = {seed_a, seed_b, seed_c, seed_d}

    output = format_output(output)

    {save, output, seed}
  end

  defp call_nif_with_timer(dirty_nifs, nif_atom, nif_func, dirty_nif_func, arguments) do
    if nif_atom in dirty_nifs do
      :timer.tc(dirty_nif_func, arguments)
    else
      :timer.tc(nif_func, arguments)
    end
  end

  defp call_zmachine_nifs_with_diagnostics(story, save, input, seed, dirty_nifs) do
    {seed_nif_microsec, {seed_a, seed_b, seed_c, seed_d}} =
      case seed do
        {seed_a, seed_b, seed_c, seed_d}
        when is_integer(seed_a) and is_integer(seed_b) and is_integer(seed_c) and
               is_integer(seed_d) ->
          {0, {seed_a, seed_b, seed_c, seed_d}}

        _ ->
          call_nif_with_timer(
            dirty_nifs,
            :generate_zmachine_random_seed,
            &EncrustedNif.generate_zmachine_random_seed/0,
            &EncrustedNif.generate_zmachine_random_seed_dirty_cpu/0,
            []
          )
      end

    {init_nif_microsec, zmachine} =
      call_nif_with_timer(
        dirty_nifs,
        :init_zmachine,
        &EncrustedNif.init_zmachine/6,
        &EncrustedNif.init_zmachine_dirty_cpu/6,
        [story, save, seed_a, seed_b, seed_c, seed_d]
      )

    {step_1_nif_microsec, step_1} =
      call_nif_with_timer(
        dirty_nifs,
        :step_zmachine,
        &EncrustedNif.step_zmachine/1,
        &EncrustedNif.step_zmachine_dirty_cpu/1,
        [zmachine]
      )

    {send_nif_microsec, unicode_table_nif_microsec, unicode_table} =
      case step_1 do
        "ReadLine" ->
          {send_nif_microsec, {}} =
            call_nif_with_timer(
              dirty_nifs,
              :send_line_to_zmachine,
              &EncrustedNif.send_line_to_zmachine/2,
              &EncrustedNif.send_line_to_zmachine_dirty_cpu/2,
              [zmachine, input]
            )

          {send_nif_microsec, 0, nil}

        "ReadChar" ->
          {unicode_table_nif_microsec, unicode_table} =
            call_nif_with_timer(
              dirty_nifs,
              :compute_zmachine_unicode_table,
              &EncrustedNif.compute_zmachine_unicode_table/1,
              &EncrustedNif.compute_zmachine_unicode_table_dirty_cpu/1,
              [zmachine]
            )

          {send_nif_microsec, {}} =
            call_nif_with_timer(
              dirty_nifs,
              :send_char_to_zmachine,
              &EncrustedNif.send_char_to_zmachine/3,
              &EncrustedNif.send_char_to_zmachine_dirty_cpu/3,
              [zmachine, input, unicode_table]
            )

          {send_nif_microsec, unicode_table_nif_microsec, unicode_table}

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    {step_2_nif_microsec, step_2} =
      call_nif_with_timer(
        dirty_nifs,
        :step_zmachine,
        &EncrustedNif.step_zmachine/1,
        &EncrustedNif.step_zmachine_dirty_cpu/1,
        [zmachine]
      )

    {output_nif_microsec, output} =
      call_nif_with_timer(
        dirty_nifs,
        :drain_zmachine_output,
        &EncrustedNif.drain_zmachine_output/1,
        &EncrustedNif.drain_zmachine_output_dirty_cpu/1,
        [zmachine]
      )

    {save_nif_microsec, save} =
      call_nif_with_timer(
        dirty_nifs,
        :save_zmachine_state,
        &EncrustedNif.save_zmachine_state/1,
        &EncrustedNif.save_zmachine_state_dirty_cpu/1,
        [zmachine]
      )

    # Note: Save NIF returns Vec[u8] directly for simplicity,
    # so we need to convert from list to Elixir binary here:
    save = :binary.list_to_bin(save)

    seed = {seed_a, seed_b, seed_c, seed_d}

    diagnostics = %{
      seed_nif: [{seed_nif_microsec / 1000, input, output, seed}],
      init_nif: [{init_nif_microsec / 1000, input, output, zmachine}],
      step_1_nif: [{step_1_nif_microsec / 1000, input, output, step_1}],
      send_line_nif: [{nil, input, output, {}}],
      send_char_nif: [{nil, input, output, {}}],
      unicode_table_nif: [{nil, input, output, nil}],
      step_2_nif: [{step_2_nif_microsec / 1000, input, output, step_2}],
      output_nif: [{output_nif_microsec / 1000, input, output, output}],
      save_nif: [{save_nif_microsec / 1000, input, output, save}]
    }

    diagnostics =
      case step_1 do
        "ReadLine" ->
          %{diagnostics | send_line_nif: [{send_nif_microsec / 1000, input, output, {}}]}

        "ReadChar" ->
          %{
            diagnostics
            | send_char_nif: [{send_nif_microsec / 1000, input, output, {}}],
              unicode_table_nif: [
                {unicode_table_nif_microsec / 1000, input, output, unicode_table}
              ]
          }

        unexpected ->
          raise(RuntimeError, "unexpected ZMachine step (#{unexpected})")
      end

    output = format_output(output)

    {save, output, seed, diagnostics}
  end
end
