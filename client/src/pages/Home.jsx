import React from 'react';
import Navbar from '../components/Navbar';
import "../styles/index.css"
import "../styles/Home.css"
import "../styles/styles.css"
import jaxklogo from '../assets/images/jaxklogo.png';
import neptune from '../assets/images/neptune.png';


function Home() {
  return (
    <div style={{ minHeight: '100vh' }}>  {/* Light background color */}
      <Navbar />
      <div className="container mt-4">
      <h2 className="homeText">
           Welcome to JaxK Corp      
      </h2>
        <p style={{ margin: '60px',textAlign: 'center', fontSize: '20px', color: '#555',  fontFamily: '"Tagesschrift", system-ui' }}> 
          This is the home page. Implemented and Designed by Joe Black.
        </p>
        <img src={jaxklogo} alt="JaxK Logo" className="JaxKLogo" />
        
      </div>    
    </div>
  );
}



export default Home;
