# These steps are to be pasted in by hand, not loaded as one Ruby file.

# Load the data.

load "init.rb"
load "raw_data.rb"

# Load the code that can do reweighted Score tallying.

load "solve.rb"

# Convert the ranked ballots to score ballots and run the first round of the
# score election.

r1 = Round.new
r1.be_first
r1.winners

# Two rounds with reweighting to extract the other two winners.

r2 = r1.next_round
r2.winners

r3 = r2.next_round
r3.winners

