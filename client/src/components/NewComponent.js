import { useState } from 'react';



function NewComponent() { 
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
  
    const handleComponent = async (e) => {
      e.preventDefault();
      try {
        // functionality can be added
      } catch (err) {
        setError(err.message);
      }
    };



    return (

        <div style={{ padding: '2rem' }}>
        <h1>Jaxk </h1>
        



      </div>


    );

}


export default NewComponent;