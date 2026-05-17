import { NavLink, Outlet } from 'react-router-dom'
import { WalletConnect } from './WalletConnect'

export function Layout() {
  return (
    <div className="app-layout">
      <header className="app-header">
        <div className="header-inner">
          <NavLink to="/" className="logo">
            <span className="logo-icon">◆</span>
            <span className="logo-text">InsureDAO</span>
          </NavLink>

          <nav className="main-nav">
            <NavLink to="/" end className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
              Dashboard
            </NavLink>
            <NavLink to="/insure" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
              Insure
            </NavLink>
            <NavLink to="/underwrite" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
              Underwrite
            </NavLink>
            <NavLink to="/governance" className={({ isActive }) => isActive ? 'nav-link active' : 'nav-link'}>
              Governance
            </NavLink>
          </nav>

          <WalletConnect />
        </div>
      </header>

      <main className="app-main">
        <Outlet />
      </main>

      <footer className="app-footer">
        <p>InsureDAO Protocol — Decentralized Insurance on Arbitrum</p>
      </footer>
    </div>
  )
}
