import React from 'react';
import { Link } from 'react-router-dom';
import SearchBar from './SearchBar';
import "../styles/NavbarStyles.css"; // Make sure styles are loaded

function Navbar() {
  return (
    <nav className="navbar navbar-expand-lg">
      <div className="container-fluid">
        {/* Logo and Brand Name */}
        <Link className="navbar-brand" to="/">
          JaxK Corp
        </Link>

        {/* Toggle button for mobile view */}
        <button
          className="navbar-toggler"
          type="button"
          data-bs-toggle="collapse"
          data-bs-target="#navbarNav"
          aria-controls="navbarNav"
          aria-expanded="false"
          aria-label="Toggle navigation"
        >
          <span className="navbar-toggler-icon"></span>
        </button>

        {/* Navbar Links and Search Bar */}
        <div className="collapse navbar-collapse" id="navbarNav">
          <ul className="navbar-nav ms-auto mb-2 mb-lg-0">
            <li className="nav-item">
              <Link className="nav-link active" aria-current="page" to="/">Home</Link>
            </li>
            <li className="nav-item">
              <Link className="nav-link" to="/dashboard">Dashboard</Link>
            </li>
            <li className="nav-item">
              <Link className="nav-link" to="/register">Register</Link>
            </li>
          </ul>

          {/* SearchBar sits nicely here */}
          <div className="d-flex ms-3">
            <SearchBar />
          </div>
        </div>
      </div>
    </nav>
  );
}

export default Navbar;
