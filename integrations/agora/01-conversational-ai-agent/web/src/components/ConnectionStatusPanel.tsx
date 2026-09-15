'use client';

import {
  ConversationErrorCard,
  type ConnectionIssue,
} from '@/components/ConversationErrorCard';

type ConnectionStatusPanelProps = {
  connectionState: string;
  connectionSeverity: 'normal' | 'warning' | 'error';
  connectionIssues: ConnectionIssue[];
  isOpen: boolean;
  onToggle: () => void;
};

function getConnectionLabel(
  connectionState: string,
  connectionSeverity: 'normal' | 'warning' | 'error',
) {
  if (connectionSeverity !== 'normal' && connectionState === 'CONNECTED') {
    return 'Connected (issues detected)';
  }
  if (connectionState === 'CONNECTED') return 'Connected';
  if (connectionState === 'CONNECTING') return 'Connecting...';
  if (connectionState === 'RECONNECTING') return 'Reconnecting...';
  if (connectionState === 'DISCONNECTING') return 'Disconnecting...';
  return 'Disconnected';
}

export function ConnectionStatusPanel({
  connectionState,
  connectionSeverity,
  connectionIssues,
  isOpen,
  onToggle,
}: ConnectionStatusPanelProps) {
  return (
    <div className="relative flex-shrink-0">
      <button
        type="button"
        className="relative block"
        aria-label={getConnectionLabel(connectionState, connectionSeverity)}
        aria-expanded={isOpen}
        aria-controls="connection-details-panel"
        onClick={onToggle}
      >
        <span className="relative flex h-2 w-2">
          {connectionState !== 'DISCONNECTED' &&
            connectionState !== 'DISCONNECTING' && (
              <span
                className={`absolute inline-flex h-full w-full animate-ping rounded-full opacity-75 ${
                  connectionSeverity === 'normal'
                    ? 'bg-green-500'
                    : connectionSeverity === 'warning'
                      ? 'bg-amber-500'
                      : 'bg-red-500'
                }`}
              />
            )}
          <span
            className={`relative inline-flex h-2 w-2 rounded-full ${
              connectionSeverity === 'normal'
                ? 'bg-green-500'
                : connectionSeverity === 'warning'
                  ? 'bg-amber-500'
                  : 'bg-red-500'
            }`}
          />
        </span>
      </button>

      <div
        id="connection-details-panel"
        className={`fixed top-16 left-1/2 z-20 w-[min(92vw,22rem)] -translate-x-1/2 space-y-2 rounded-md border border-border bg-card/95 p-3 backdrop-blur-sm transition-opacity md:absolute md:top-full md:left-0 md:mt-3 md:w-[24rem] md:translate-x-0 md:translate-y-0 ${
          isOpen
            ? 'pointer-events-auto opacity-100'
            : 'pointer-events-none opacity-0'
        }`}
        role="status"
        aria-live="polite"
        aria-label="Connection details"
      >
        <div className="flex items-center justify-between gap-2">
          <div className="text-xs font-semibold tracking-wide text-foreground">
            Connection Details
          </div>
          <div className="text-[11px] text-muted-foreground">
            RTC {connectionState.toLowerCase()}
          </div>
        </div>

        {connectionIssues.length === 0 ? (
          <div className="text-xs text-muted-foreground">
            No RTM or agent errors reported.
          </div>
        ) : (
          <div className="max-h-56 space-y-2 overflow-auto pr-1">
            {connectionIssues.map((issue) => (
              <ConversationErrorCard key={issue.id} issue={issue} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
