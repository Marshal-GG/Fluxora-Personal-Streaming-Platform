sealed class PairState {
  const PairState();
}

class PairInitial extends PairState {
  const PairInitial();
}

class PairRequesting extends PairState {
  const PairRequesting();
}

class PairPending extends PairState {
  const PairPending();
}

class PairApproved extends PairState {
  const PairApproved();
}

class PairRejected extends PairState {
  const PairRejected(this.reason);

  final String reason;
}

class PairError extends PairState {
  const PairError(this.message);

  final String message;
}
