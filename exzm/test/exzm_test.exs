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
    Utils.play_adventure_with_diagnostics()
    Utils.play_anchorhead_with_diagnostics()
    Utils.play_anchorhead_with_diagnostics()
    Utils.play_adventure_with_diagnostics()
    Utils.play_anchorhead_with_diagnostics()
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

  def play_adventure(opts \\ []) do
    story = load_story("advent.z3")

    {save, output} =
      if opts == [] do
        Exzm.new_game(story)
      else
        Exzm.new_game(story, "", opts)
      end

    assert output =~ "Welcome to Adventure!"
    assert output =~ "Do you need instructions? (y/n)"
    {save, output} = Exzm.continue(story, save, "y", opts)
    assert output =~ "Direct me with simple commands, like NORTH"
    assert output =~ "ADVENTURE"
    assert output =~ "A Modern Classic"
    assert output =~ "At End Of Road"
    {save, output} = Exzm.continue(story, save, "north", opts)
    assert output =~ "In Forest"
    {save, output} = Exzm.continue(story, save, "E", opts)
    assert output =~ "In A Valley"
    assert byte_size(save) > 0
  end

  def play_anchorhead(opts \\ []) do
    story = load_story("anchor.z8")

    {save, output} =
      if opts == [] do
        Exzm.new_game(story)
      else
        Exzm.new_game(story, "", opts)
      end

    assert output =~ "November, 1997."
    assert output =~ "You take a deep breath of salty air"
    assert output =~ "Welcome to Anchorhead..."
    {save, output} = Exzm.continue(story, save, "", opts)

    expect_blank_step = !Keyword.get(opts, :step_through_blank)

    {save, output} =
      if expect_blank_step do
        # Step through blank step manually:
        assert output == ""
        Exzm.continue(story, save, "", opts)
      else
        # No blank step expected because :step_through_blank was used; do nothing.
        {save, output}
      end

    assert output =~ "ANCHORHEAD"
    assert output =~ "An interactive gothic"
    assert output =~ "Type HELP or ABOUT for some useful information."
    assert output =~ "Outside the Real Estate Office"
    {save, output} = Exzm.continue(story, save, "north", opts)
    assert output =~ "The street goes west from here."
    assert output =~ "You can enter the office to the east"
    {save, output} = Exzm.continue(story, save, "E", opts)
    assert output =~ "(opening the real estate office door first)"
    assert output =~ "It seems to be locked."
    assert byte_size(save) > 0
  end

  def play_adventure_with_diagnostics() do
    story = load_story("advent.z3")
    opts = [diagnostics: true]
    {save, output, diagnostics} = Exzm.new_game(story, "", opts)
    assert output =~ "Welcome to Adventure!"
    assert output =~ "Do you need instructions? (y/n)"
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "y", opts)
    assert output =~ "Direct me with simple commands, like NORTH"
    assert output =~ "ADVENTURE"
    assert output =~ "A Modern Classic"
    assert output =~ "At End Of Road"
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "north", opts)
    assert output =~ "In Forest"
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "E", opts)
    assert output =~ "In A Valley"
    assert byte_size(save) > 0
    assert is_number(diagnostics.nif_duration_ms)
  end

  def play_anchorhead_with_diagnostics() do
    story = load_story("anchor.z8")
    opts = [diagnostics: true]
    {save, output, diagnostics} = Exzm.new_game(story, "", opts)
    assert output =~ "November, 1997."
    assert output =~ "You take a deep breath of salty air"
    assert output =~ "Welcome to Anchorhead..."
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "", opts)
    # Expect a blank step here because we're not setting :step_through_blank
    assert output == ""
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "", opts)
    assert output =~ "ANCHORHEAD"
    assert output =~ "An interactive gothic"
    assert output =~ "Type HELP or ABOUT for some useful information."
    assert output =~ "Outside the Real Estate Office"
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "north", opts)
    assert output =~ "The street goes west from here."
    assert output =~ "You can enter the office to the east"
    assert is_number(diagnostics.nif_duration_ms)
    {save, output, diagnostics} = Exzm.continue(story, save, "E", opts)
    assert output =~ "(opening the real estate office door first)"
    assert output =~ "It seems to be locked."
    assert byte_size(save) > 0
    assert is_number(diagnostics.nif_duration_ms)
  end
end
