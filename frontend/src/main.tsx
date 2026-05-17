import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'

import { config } from './config/wagmi'
import { ErrorBoundary } from './components/ErrorBoundary'
import { Layout } from './components/Layout'
import { Dashboard } from './pages/Dashboard'
import { InsurePage } from './pages/InsurePage'
import { UnderwritePage } from './pages/UnderwritePage'
import { GovernancePage } from './pages/GovernancePage'

import './App.css'

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      staleTime: 15_000,
      refetchOnWindowFocus: false,
    },
  },
})

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <ErrorBoundary>
          <BrowserRouter>
            <Routes>
              <Route element={<Layout />}>
                <Route index element={<Dashboard />} />
                <Route path="insure" element={<InsurePage />} />
                <Route path="underwrite" element={<UnderwritePage />} />
                <Route path="governance" element={<GovernancePage />} />
              </Route>
            </Routes>
          </BrowserRouter>
        </ErrorBoundary>
      </QueryClientProvider>
    </WagmiProvider>
  </StrictMode>
)
