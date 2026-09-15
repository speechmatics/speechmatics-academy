import {
  type AgentState,
  type AgentTranscription,
  TurnStatus,
  type TranscriptHelperItem,
  type UserTranscription,
} from 'agora-agent-client-toolkit'
import {
  type AgentVisualizerState,
  type IMessageListItem,
} from 'agora-agent-uikit'

export function normalizeTranscriptSpacing(text: string): string {
  return text
    .replace(/([.!?])([A-Za-z])/g, '$1 $2')
    .replace(/,([A-Za-z])/g, ', $1')
    .replace(/\s{2,}/g, ' ')
    .trim()
}

export function normalizeTimestampMs(timestamp: number): number {
  return timestamp > 1e12 ? timestamp : timestamp * 1000
}

export function mapAgentVisualizerState(
  agentState: AgentState | null,
  isAgentConnected: boolean,
  connectionState: string,
): AgentVisualizerState {
  if (connectionState === 'DISCONNECTED' || connectionState === 'DISCONNECTING') {
    return 'disconnected'
  }

  if (connectionState === 'CONNECTING' || connectionState === 'RECONNECTING') {
    return 'joining'
  }

  if (!isAgentConnected) {
    return 'not-joined'
  }

  switch (agentState) {
    case 'listening':
      return 'listening'
    case 'thinking':
      return 'analyzing'
    case 'speaking':
      return 'talking'
    case 'idle':
    case 'silent':
    default:
      return 'ambient'
  }
}

function toMessageListItem(
  item: TranscriptHelperItem<Partial<UserTranscription | AgentTranscription>>,
): IMessageListItem {
  return {
    turn_id: item.turn_id,
    uid: Number(item.uid) || 0,
    text: typeof item.text === 'string' ? item.text : '',
    status: item.status as unknown as IMessageListItem['status'],
    createdAt:
      typeof item._time === 'number'
        ? normalizeTimestampMs(item._time)
        : undefined,
  }
}

export function normalizeTranscript(
  transcript: TranscriptHelperItem<Partial<UserTranscription | AgentTranscription>>[],
  localUid: string,
) {
  return transcript.map((item) => {
    const nextUid = item.uid === '0' ? localUid : item.uid
    const nextText =
      typeof item.text === 'string' ? normalizeTranscriptSpacing(item.text) : item.text

    return { ...item, uid: nextUid, text: nextText }
  })
}

export function getMessageList(
  transcript: TranscriptHelperItem<Partial<UserTranscription | AgentTranscription>>[],
) {
  return transcript
    .filter((item) => item.status !== TurnStatus.IN_PROGRESS)
    .map(toMessageListItem)
}

export function getCurrentInProgressMessage(
  transcript: TranscriptHelperItem<Partial<UserTranscription | AgentTranscription>>[],
) {
  const item = transcript.find((entry) => entry.status === TurnStatus.IN_PROGRESS)
  return item ? toMessageListItem(item) : null
}
