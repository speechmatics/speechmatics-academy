'use client'

import React from 'react'

import { Button } from '@/components/ui/button'

interface ErrorBoundaryProps {
  children: React.ReactNode
  fallback?: React.ReactNode
}

interface ErrorBoundaryState {
  hasError: boolean
  error?: Error
}

export class ErrorBoundary extends React.Component<
  ErrorBoundaryProps,
  ErrorBoundaryState
> {
  constructor(props: ErrorBoundaryProps) {
    super(props)
    this.state = { hasError: false }
  }

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error }
  }

  componentDidCatch(error: Error, errorInfo: React.ErrorInfo) {
    console.error('ErrorBoundary caught an error:', error, errorInfo)
  }

  render() {
    if (this.state.hasError) {
      if (this.props.fallback) {
        return this.props.fallback
      }

      return (
        <div className='flex min-h-[320px] flex-col items-center justify-center p-8 text-center'>
          <div className='max-w-md'>
            <h2 className='mb-4 text-lg font-semibold text-destructive'>Something went wrong</h2>
            <p className='mb-6 text-sm text-muted-foreground'>
              An error occurred while loading the conversation. Please try refreshing the
              page.
            </p>
            <Button onClick={() => window.location.reload()}>Refresh Page</Button>
          </div>
        </div>
      )
    }

    return this.props.children
  }
}
