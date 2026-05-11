import { ErrorBoundary, type FallbackProps } from 'react-error-boundary'
import { Card, CardContent } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { RefreshCw } from 'lucide-react'

// Per-tab boundary: when one tab crashes (TSL shader error, bad API
// response, …) only that tab goes red; the rest of the dashboard stays
// usable and the user can retry without a full reload.
export function TabBoundary({ children }: { children: React.ReactNode }) {
  return <ErrorBoundary FallbackComponent={Fallback}>{children}</ErrorBoundary>
}

function Fallback({ error, resetErrorBoundary }: FallbackProps) {
  return (
    <Card>
      <CardContent className="p-4 space-y-3">
        <div className="text-sm text-destructive font-medium">
          This tab crashed.
        </div>
        <pre className="text-xs text-muted-foreground whitespace-pre-wrap max-h-[300px] overflow-auto bg-muted/30 p-2 rounded-md">
          {error instanceof Error ? `${error.name}: ${error.message}\n\n${error.stack ?? ''}` : String(error)}
        </pre>
        <Button size="sm" variant="outline" onClick={resetErrorBoundary}>
          <RefreshCw className="size-3" /> Retry
        </Button>
      </CardContent>
    </Card>
  )
}
