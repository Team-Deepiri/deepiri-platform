import React from 'react';


function SearchBar() {
  return (
    <div className="d-flex justify-content-center my-3">
      <input
        className="form-control me-2"
        type="search"
        placeholder="Search"
        aria-label="Search"
      />
      <button className="btn btn-outline-primary" type="submit">
        Search
      </button>
    </div>
  );
}

export default SearchBar;