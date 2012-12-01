class ScoreBallot < ElectoralObject
  # A score ballot can provide a score for any candidate.
  attr_accessor :scores_by_candidate
  attr_accessor :weight, :ranking_ballot
  def initialize
    @scores_by_candidate = Hash.new
    @weight = 1.0
  end
  def score_for_candidate a_candidate
    (scores_by_candidate[a_candidate] || 0.0) * weight
  end
  def from_ranking_ballot a_ranking_ballot
    # Initialize my content from the given ranking ballot.
    raw_rank_count = a_ranking_ballot.candidates_by_one_based_rank.size
    raw_rank_count == a_ranking_ballot.one_based_ranks_by_candidate.size ||
      (throw "Ranking ballot not initialized coherently.  " + a_ranking_ballot.voter_name)
    interpreted_rank_count = raw_rank_count + 1 # for the other candiates.
    interpreted_interval_count = interpreted_rank_count - 1
      # The rank count includes both end ranks; the interval count is one less.
      # It's like how a "seven-point" saw only has six intervals between points, per inch.
    if 0 != interpreted_interval_count
      interval = 1.0 / interpreted_interval_count.to_f
      (1..raw_rank_count).each do | obr | # one-based rank
        hit = a_ranking_ballot.candidates_by_one_based_rank[obr]
        hit || (throw "Missing rank in ballot.  " + a_ranking_ballot.voter_name)
        scores_by_candidate[hit] = 1.0 - interval * (raw_rank_count - obr).to_f
      end
    end
    # the other candidates get a score of zero when queried, by default.
    self.ranking_ballot = a_ranking_ballot # Maybe just for debugging.
  end
  def deweighted_with_winners some_winners
    # Answer with a ballot similar to myself but with weight determined by
    # some_winners as canddidates who have already won in prior rounds of the
    # multi-winner election.
    sum = some_winners.inject(0.0) do | acc, a_winner |
      acc + (score_for_candidate a_winner)
    end
    new_weight = 0.5 / (0.5 + sum)
    if new_weight == weight
      self
    else
      n = self.class.allocate
      n.scores_by_candidate = scores_by_candidate
      n.ranking_ballot      = ranking_ballot
      n.weight              = new_weight
      n
    end
  end
end

class RoundCandidateTally
  # The purpose of a round candidate tally is to calculate the total score that
  # a candidate receives in a round.
  attr_accessor :candidate, :round
  def score
    @score ||= lambda do
      acc = 0.0
      base = 0.0
      round.ballots.each do | a_ballot |
        acc += a_ballot.score_for_candidate candidate
        base += a_ballot.weight
      end
      acc / base
    end.call
  end
  def inspect
    if @candidate
      "{" + score.to_s + " " + candidate.name + "}"
    else
      "{an uninitialized tally object}"
    end
  end
end

class Round < ElectoralObject
  # An instance represents a round of tallying for a multi-winner election.

  attr_accessor :ballots, :candidates, :ordinal
  attr_writer :prior_winners

  def prior_winners
    # What candidates already won on prior rounds?
    @prior_winners ||= []
  end

  def be_first
    # Model the first round in the election.
    self.ordinal = 1
    self.candidates = election.candidates_by_name.values
    self.ballots = election.ballots_by_voter_name.values.map do | a_ranking_ballot |
      it = ScoreBallot.new
      it.from_ranking_ballot a_ranking_ballot
      it
    end
    true
  end

  def follow prior_round
    # Be the round that follows prior_round.
    self.ordinal = prior_round.ordinal + 1
    self.prior_winners = prior_round.prior_winners + prior_round.winners.map(&:candidate)
    self.ballots = prior_round.ballots.map {|e|e.deweighted_with_winners prior_winners}
    self.candidates = prior_round.candidates - prior_winners
    true
  end

  def inspect
    if ordinal
      "{round #{ordinal}}"
    else
      "{a round}"
    end
  end

  def tallies
    @tallies ||= lambda do
      candidates.map do | a_candidate |
        n = RoundCandidateTally.new
        n.round     = self
        n.candidate = a_candidate
        n
      end
    end.call
  end

  def ordered_tallies
    tallies.sort_by {|t| 0.0 - t.score}
  end

  def winners
    @winners ||= lambda do
      ordered_tallies = self.ordered_tallies
      acc = []
      unless ordered_tallies.empty?
        cur = 0
        hit = ordered_tallies[cur]
        top_score = hit.score
        while hit.score >= top_score
          acc += [hit]
          cur += 1
          hit = ordered_tallies[cur]
        end # while
      end # unless
      acc
    end.call
  end # def

  def next_round
    r = Round.new
    r.follow self
    r
  end
end # class
