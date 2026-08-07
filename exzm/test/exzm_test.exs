defmodule ExzmTest do
  use ExUnit.Case
  alias ExzmTest.Utils
  doctest Exzm

  test "starts new games and continues them sucessfully" do
    Utils.play_adventure()
    Utils.play_anchorhead()
    Utils.play_anchorhead()
    Utils.play_adventure()
    Utils.play_anchorhead()
  end

  test ":step_through_blank option works as expected" do
    Utils.play_adventure(step_through_blank: true)
    Utils.play_anchorhead(step_through_blank: true)
    Utils.play_anchorhead(step_through_blank: true)
    Utils.play_adventure(step_through_blank: true)
    Utils.play_anchorhead(step_through_blank: true)
  end

  test ":diagnostics option works as expected" do
    Utils.play_adventure(diagnostics: true)
    Utils.play_anchorhead(diagnostics: true)
    Utils.play_anchorhead(diagnostics: true)
    Utils.play_adventure(diagnostics: true)
    Utils.play_anchorhead(diagnostics: true)
  end

  test "all options set together work as expected" do
    Utils.play_adventure(step_through_blank: true, diagnostics: true)
    Utils.play_anchorhead(step_through_blank: true, diagnostics: true)
    Utils.play_anchorhead(step_through_blank: true, diagnostics: true)
    Utils.play_adventure(step_through_blank: true, diagnostics: true)
    Utils.play_anchorhead(step_through_blank: true, diagnostics: true)
  end
end

defmodule ExzmTest.Utils do
  use ExUnit.Case

  defp load_story(story_file) do
    case File.read(Path.join("../stories", story_file)) do
      {:ok, story} -> story
      _ -> raise "Failed to read story file."
    end
  end

  defp with_diagnostics_or_nil(result) do
    case result do
      {save, output, seed} -> {save, output, seed, nil}
      {save, output, seed, diagnostics} -> {save, output, seed, diagnostics}
    end
  end

  defp assert_valid_diagnostics(diagnostics?, diagnostics) do
    if diagnostics? do
      assert is_number(diagnostics.prime_nif_ms)
      assert diagnostics.prime_nif_ms >= 0
      assert diagnostics.send_line_nif_ms >= 0
      assert diagnostics.send_char_nif_ms >= 0
    end
  end

  def play_adventure(opts \\ []) do
    story = load_story("advent.z3")
    diagnostics? = Keyword.get(opts, :diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(
        case opts do
          [] -> Exzm.new_game(story)
          _ -> Exzm.new_game(story, "", opts)
        end
      )

    assert output =~ "Welcome to Adventure!"
    assert output =~ "Do you need instructions? (y/n)"

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(Exzm.continue(story, save, "y", opts))

    assert output =~ "Direct me with simple commands, like NORTH"
    assert output =~ "ADVENTURE"
    assert output =~ "A Modern Classic"
    assert output =~ "At End Of Road"

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(Exzm.continue(story, save, "north", opts))

    assert output =~ "In Forest"

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(Exzm.continue(story, save, "E", opts))

    assert output =~ "In A Valley"
    assert byte_size(save) > 0

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)
  end

  def play_anchorhead(opts \\ []) do
    story = load_story("anchor.z8")
    diagnostics? = Keyword.get(opts, :diagnostics)
    expect_blank_step = !Keyword.get(opts, :step_through_blank)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(
        case opts do
          [] -> Exzm.new_game(story)
          _ -> Exzm.new_game(story, "", opts)
        end
      )

    assert output =~ "November, 1997."
    assert output =~ "You take a deep breath of salty air"
    assert output =~ "Welcome to Anchorhead..."

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(Exzm.continue(story, save, "", opts))

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      if expect_blank_step do
        # Step through blank step manually:
        assert output == ""
        with_diagnostics_or_nil(Exzm.continue(story, save, "", opts))
      else
        # No blank step expected because :step_through_blank was used; do nothing.
        {save, output, seed, diagnostics}
      end

    assert output =~ "ANCHORHEAD"
    assert output =~ "An interactive gothic"
    assert output =~ "Type HELP or ABOUT for some useful information."
    assert output =~ "Outside the Real Estate Office"

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(Exzm.continue(story, save, "north", opts))

    assert output =~ "The street goes west from here."
    assert output =~ "You can enter the office to the east"

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)

    {save, output, seed, diagnostics} =
      with_diagnostics_or_nil(Exzm.continue(story, save, "E", opts))

    assert output =~ "(opening the real estate office door first)"
    assert output =~ "It seems to be locked."
    assert byte_size(save) > 0

    assert match?(
             {a, b, c, d}
             when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d),
             seed
           )

    assert_valid_diagnostics(diagnostics?, diagnostics)
  end
end
