/// Speechmatics job lifecycle state (from `GET /v2/jobs/{id}` -> job.status).
enum JobState { running, done, rejected, deleted, expired, unknown }

class JobStatus {
  const JobStatus(this.state, {this.error, this.durationSeconds});

  final JobState state;
  final String? error;
  final int? durationSeconds;

  bool get isTerminal => state != JobState.running;
  bool get isDone => state == JobState.done;

  factory JobStatus.fromJob(Map<String, dynamic> job) {
    final raw = (job['status'] ?? '').toString();
    final state = switch (raw) {
      'running' => JobState.running,
      'done' => JobState.done,
      'rejected' => JobState.rejected,
      'deleted' => JobState.deleted,
      'expired' => JobState.expired,
      _ => JobState.unknown,
    };
    String? error;
    final errors = job['errors'];
    if (errors is List && errors.isNotEmpty) {
      error = errors.map((e) => e is Map ? (e['message'] ?? e).toString() : e.toString()).join('; ');
    }
    return JobStatus(
      state,
      error: error,
      durationSeconds: (job['duration'] as num?)?.round(),
    );
  }
}
