/// A term → definition pair used by the Concept Matching activity.
///
/// Pairs are derived from the user's own lesson content (formula/concept labels
/// and expressions), so the mini-game always reflects their workspace.
class MatchingPair {
  const MatchingPair({
    required this.id,
    required this.term,
    required this.definition,
  });

  final String id;
  final String term;
  final String definition;
}
