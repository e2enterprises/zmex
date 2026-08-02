defmodule ExzmTest do
  use ExUnit.Case
  doctest Exzm

  defp load_story_data(story_file) do
    case File.read(Path.join("../stories", story_file)) do
      {:ok, story_data} -> story_data
      _ -> raise "Failed to read story file."
    end
  end

  test "starts a new game, then continues sucessfully (adventure)" do
    story_data = load_story_data("advent.z3")

    play_game = fn ->
      {save_data, output} = Exzm.new_game(story_data)
      assert output =~ "Welcome to Adventure!"
      assert output =~ "Do you need instructions? (y/n)"
      {save_data, output} = Exzm.continue(story_data, save_data, "y")
      assert output =~ "Direct me with simple commands, like NORTH"
      assert output =~ "ADVENTURE"
      assert output =~ "A Modern Classic"
      assert output =~ "At End Of Road"
      {save_data, output} = Exzm.continue(story_data, save_data, "north")
      assert output =~ "In Forest"
      {save_data, output} = Exzm.continue(story_data, save_data, "E")
      assert output =~ "In A Valley"
      assert byte_size(save_data) > 0
    end

    # Run through game thrice to ensure resets operate as expected:
    play_game.()
    play_game.()
    play_game.()
  end

  test "starts a new game, then continues sucessfully (anchorhead)" do
    story_data = load_story_data("anchor.z8")

    play_game = fn ->
      {save_data, output} = Exzm.new_game(story_data)
      assert output =~ "November, 1997."
      assert output =~ "You take a deep breath of salty air"
      assert output =~ "Welcome to Anchorhead..."
      {save_data, output} = Exzm.continue(story_data, save_data, "")
      # Note: Anchorhead has a blank screen here that needs to be stepped through.
      #       Test case below uses :step_through_blank to handle this automatically.
      assert output == ""
      {save_data, output} = Exzm.continue(story_data, save_data, "")
      assert output =~ "ANCHORHEAD"
      assert output =~ "An interactive gothic"
      assert output =~ "Type HELP or ABOUT for some useful information."
      assert output =~ "Outside the Real Estate Office"
      {save_data, output} = Exzm.continue(story_data, save_data, "north")
      assert output =~ "The street goes west from here."
      assert output =~ "You can enter the office to the east"
      {save_data, output} = Exzm.continue(story_data, save_data, "E")
      assert output =~ "(opening the real estate office door first)"
      assert output =~ "It seems to be locked."
      assert byte_size(save_data) > 0
    end

    # Run through game thrice to ensure resets operate as expected:
    play_game.()
    play_game.()
    play_game.()
  end

  test "step_through_blank: true option works as expected" do
    story_data = load_story_data("anchor.z8")
    opts = [step_through_blank: true]

    play_game = fn ->
      {save_data, output} = Exzm.new_game(story_data)
      assert output =~ "November, 1997."
      assert output =~ "You take a deep breath of salty air"
      assert output =~ "Welcome to Anchorhead..."
      # Note: Anchorhead normally has a blank screen here, but we'll set
      #       step_through_blank: true so it'll be stepped through automatically.
      {save_data, output} = Exzm.continue(story_data, save_data, "", opts)
      assert output =~ "ANCHORHEAD"
      assert output =~ "An interactive gothic"
      assert output =~ "Type HELP or ABOUT for some useful information."
      assert output =~ "Outside the Real Estate Office"
      {save_data, output} = Exzm.continue(story_data, save_data, "north")
      assert output =~ "The street goes west from here."
      assert output =~ "You can enter the office to the east"
      # Ensure step_through_blank: true doesn't have any effect for normal steps:
      {save_data, output} = Exzm.continue(story_data, save_data, "E", opts)
      assert output =~ "(opening the real estate office door first)"
      assert output =~ "It seems to be locked."
      assert byte_size(save_data) > 0
    end

    # Run through game thrice to ensure resets operate as expected:
    play_game.()
    play_game.()
    play_game.()

    # Try running through Adventure with step_through_blank: true for ALL steps,
    # to ensure that normal behavior remains exactly the same:
    story_data = load_story_data("advent.z3")

    play_game = fn ->
      {save_data, output} = Exzm.new_game(story_data, "", opts)
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

    # Run through game thrice to ensure resets operate as expected:
    play_game.()
    play_game.()
    play_game.()
  end
end
