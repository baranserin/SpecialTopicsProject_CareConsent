/**
 * Distinct messages for the result states required by S12 and the Definition of Done:
 * an empty answer must never look like a failure, and a failure must never look empty.
 */

interface EmptyStateProps {
  title: string;
  detail?: string;
}

/** A valid answer with nothing to show (e.g. no records imported yet). */
export function EmptyState({ title, detail }: EmptyStateProps) {
  return (
    <div className="state state-empty" role="status">
      <span className="state-icon" aria-hidden="true">○</span>
      <div>
        <p className="state-title">{title}</p>
        {detail && <p className="state-detail">{detail}</p>}
      </div>
    </div>
  );
}

interface ServiceUnavailableProps {
  detail?: string;
  onRetry?: () => void;
}

/** A dependency failed; nothing was released and the action can be retried safely. */
export function ServiceUnavailable({ detail, onRetry }: ServiceUnavailableProps) {
  return (
    <div className="state state-error" role="alert">
      <span className="state-icon" aria-hidden="true">!</span>
      <div>
        <p className="state-title">Service unavailable</p>
        <p className="state-detail">
          {detail ?? "The records could not be loaded."} This is a system problem, not an empty
          health history. No clinical content was released.
        </p>
        {onRetry && (
          <button type="button" className="btn btn-outline btn-sm" onClick={onRetry}>
            Try again
          </button>
        )}
      </div>
    </div>
  );
}

interface AccessDeniedProps {
  title?: string;
  detail: string;
}

/** The viewer is not permitted to see this content. No health data is loaded. */
export function AccessDenied({ title = "Access not permitted", detail }: AccessDeniedProps) {
  return (
    <div className="state state-denied" role="alert">
      <span className="state-icon" aria-hidden="true">⛔</span>
      <div>
        <p className="state-title">{title}</p>
        <p className="state-detail">{detail}</p>
      </div>
    </div>
  );
}

export function Loading({ label }: { label: string }) {
  return (
    <div className="state state-loading" role="status" aria-live="polite">
      <span className="spinner" aria-hidden="true" />
      <p className="state-title">{label}</p>
    </div>
  );
}
