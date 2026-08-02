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
end

defmodule ExzmTest.Utils do
  use ExUnit.Case

  defp load_story_data(story_file) do
    case File.read(Path.join("../stories", story_file)) do
      {:ok, story_data} -> story_data
      _ -> raise "Failed to read story file."
    end
  end

  def play_adventure(opts \\ []) do
    story_data = load_story_data("advent.z3")

    {save_data, output} =
      if opts == [] do
        Exzm.new_game(story_data)
      else
        Exzm.new_game(story_data, "", opts)
      end

    assert output =~ "Welcome to Adventure!"
    assert output =~ "Do you need instructions? (y/n)"
    {save_data, output} = Exzm.continue(story_data, save_data, "y", opts)
    assert output =~ "Direct me with simple commands, like NORTH"
    assert output =~ "ADVENTURE"
    assert output =~ "A Modern Classic"
    assert output =~ "At End Of Road"
    {save_data, output} = Exzm.continue(story_data, save_data, "north", opts)
    assert output =~ "In Forest"
    {save_data, output} = Exzm.continue(story_data, save_data, "E", opts)
    assert output =~ "In A Valley"
    assert byte_size(save_data) > 0
  end

  def play_anchorhead(opts \\ []) do
    story_data = load_story_data("anchor.z8")

    {save_data, output} =
      if opts == [] do
        Exzm.new_game(story_data)
      else
        Exzm.new_game(story_data, "", opts)
      end

    assert output =~ "November, 1997."
    assert output =~ "You take a deep breath of salty air"
    assert output =~ "Welcome to Anchorhead..."
    {save_data, output} = Exzm.continue(story_data, save_data, "", opts)

    expect_blank_step = !Keyword.get(opts, :step_through_blank)

    {save_data, output} =
      if expect_blank_step do
        # Step through blank step manually:
        assert output == ""
        Exzm.continue(story_data, save_data, "", opts)
      else
        # No blank step expected because :step_through_blank was used; do nothing.
        {save_data, output}
      end

    assert output =~ "ANCHORHEAD"
    assert output =~ "An interactive gothic"
    assert output =~ "Type HELP or ABOUT for some useful information."
    assert output =~ "Outside the Real Estate Office"
    {save_data, output} = Exzm.continue(story_data, save_data, "north", opts)
    assert output =~ "The street goes west from here."
    assert output =~ "You can enter the office to the east"
    {save_data, output} = Exzm.continue(story_data, save_data, "E", opts)
    assert output =~ "(opening the real estate office door first)"
    assert output =~ "It seems to be locked."
    assert byte_size(save_data) > 0
  end
end
