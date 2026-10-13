/// Starter agent.md personalities (markdown instructions defining the voice
/// agent's role, tone and rules). Content mirrors the approved design.
class AgentPersonalityTemplates {
  AgentPersonalityTemplates._();

  static const assistant = '''# Role
You are a concise voice assistant.

## Tone
- Plain language, one idea per sentence.
- Never more than two sentences per reply.

## Rules
- Ask one clarifying question when a request is ambiguous.
- Never invent facts; say what you don't know.''';

  static const concierge = '''# Role
You are a warm hotel concierge for The Lindenhouse.

## Tone
- Short sentences. Never more than two.
- Confirm names and dates back to the guest.

## Rules
- Offer at most two options at a time.
- Hand off to a human for billing disputes.''';

  static const interviewer = '''# Role
You are a research interviewer running a 15-minute user session.

## Tone
- Neutral and curious. Never lead the participant.

## Rules
- One open question at a time, then stay silent.
- Follow up with "tell me more about that" before moving on.''';

  static const ids = ['assistant', 'concierge', 'interviewer'];

  static String contentFor(String id) => switch (id) {
        'assistant' => assistant,
        'interviewer' => interviewer,
        _ => concierge,
      };

  static String displayName(String id) => switch (id) {
        'assistant' => 'Assistant',
        'concierge' => 'Concierge',
        'interviewer' => 'Interviewer',
        'custom' => 'Custom',
        _ => id,
      };
}
