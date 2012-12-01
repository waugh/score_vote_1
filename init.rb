$election = Object.new
class << $election
  attr_accessor :ballots_by_voter_name, :candidates_by_name, :input_tool,
    :nota
  def candidates
    candidates_by_name.values
  end
  def ballots
    ballots_by_voter_name.values
  end
  def candidate_named a_name
    candidates_by_name[a_name] ||= lambda do
      nc = Candidate.new
      nc.name = a_name
      nc
    end.call
  end
  def inspect
    "$election"
  end
end
$election.ballots_by_voter_name = Hash.new
$election.candidates_by_name    = Hash.new

class ElectoralObject
  def election
    # Answer with a reference to the election of which I serve as a component.
    $election
  end
end

class CollectionOfRankings < ElectoralObject
  attr_reader :one_based_ranks_by_candidate, :candidates_by_one_based_rank
  def initialize
    @one_based_ranks_by_candidate = Hash.new
    @candidates_by_one_based_rank = Hash.new
  end
  def candidate_name__one_based_rank candidate_name, one_based_rank
    c = election.candidate_named candidate_name
    one_based_ranks_by_candidate[c] = one_based_rank
    candidates_by_one_based_rank[one_based_rank] = c
    true
  end
end

class Ballot < ElectoralObject
  attr_accessor :voter_name, :rankings
  def initialize
    self.rankings = CollectionOfRankings.new
  end
  def rank_candidate_named__one_based_rank candidate_name, one_based_rank
    # Initialization -- modify the database to record that I rank the candidate
    # identified by the given candidate_name at the rank denoted by the given
    # one_based_rank.
    rankings.candidate_name__one_based_rank candidate_name, one_based_rank
    true
  end
  def candidates_by_one_based_rank
    rankings.candidates_by_one_based_rank
  end
  def one_based_ranks_by_candidate
    rankings.one_based_ranks_by_candidate
  end
end

class Candidate < ElectoralObject
  attr_accessor :name
  def inspect
    if name
      "{candidate " + name + "}"
    else
      "{an uninitialized candidate object}"
    end
  end
end

# Set up "i" as the input (or initialization) tool.

i = ElectoralObject.new
class << i
  def inspect
    "{the input tool}"
  end
  def voter who
    # Accept a data declaration that there is a voter named who.
    # Answer with a mutable object to represent the voter's ballot.
    # This method has side effects and returns a result, a combination I don't
    # usually like.  But it is used in initialization.
    hit = election.ballots_by_voter_name[who]
    unless hit
      nb = Ballot.new
      nb.voter_name = who
      election.ballots_by_voter_name[who] = hit = nb
    end
    hit
  end
  def voter_rank_candidate voter_name, one_based_rank, candidate_name
    b = voter voter_name # ballot placed in database
    b.rank_candidate_named__one_based_rank candidate_name, one_based_rank
  end
end
$election.input_tool = i
# $election.nota = $election.candidate_named "None of these candidates."
