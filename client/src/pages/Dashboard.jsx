import React, { useState, useEffect } from 'react';
import {
  createData,
  getAllData,
  updateData,
  deleteData,
} from '../api/firebaseApi';

import jaxklogo from '../assets/images/jaxklogo.png';
import clairelogo from '../assets/images/cute.jpg';
import logo from '../assets/images/logo.svg';
import Navbar from '../components/Navbar';
import SearchBar from '../components/SearchBar';
import "../styles/styles.css"

function Dashboard() {
  const [data, setData] = useState([]);
  const [formData, setFormData] = useState({ title: '', content: '' });
  const [editingId, setEditingId] = useState(null);

  useEffect(() => {
    fetchData();
  }, []);

  const fetchData = async () => {
    try {
      const allData = await getAllData();
      if (Array.isArray(allData)) setData(allData);
    } catch (error) {
      console.error('Error fetching data:', error);
    }
  };

  const handleInputChange = (e) => {
    const { name, value } = e.target;
    setFormData((prev) => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingId) {
        await updateData(editingId, formData);
        setEditingId(null);
      } else {
        await createData(formData);
      }
      setFormData({ title: '', content: '' });
      fetchData();
    } catch (error) {
      console.error('Error saving data:', error);
    }
  };

  const handleEdit = (item) => {
    setFormData({ title: item.title, content: item.content });
    setEditingId(item.id);
  };

  const handleDelete = async (id) => {
    try {
      await deleteData(id);
      fetchData();
    } catch (error) {
      console.error('Error deleting data:', error);
    }
  };

  return (
    <div>
     <Navbar />
      <h2 style={{ textAlign: 'center', color: 'purple', fontSize: '60pt' ,  fontFamily: '"Tagesschrift", system-ui'}}>
        Dashboard
      </h2>
      {/* <p className="Claire">
        UI designed by Claire Hudson and implemented by Joe Black
      </p> */}
      <img src={jaxklogo} alt="JaxK Logo" className="JaxKLogo" />
      {/* <img src={clairelogo} alt="Claire Logo" /> */}
      <img src={logo} alt="Logo" />

      <form onSubmit={handleSubmit} className="form">
        <input
          type="text"
          name="title"
          value={formData.title}
          onChange={handleInputChange}
          placeholder="Title"
          required
        />
        <textarea
          name="content"
          value={formData.content}
          onChange={handleInputChange}
          placeholder="Content"
          required
        />
        <button type="submit">{editingId ? 'Update' : 'Create'}</button>
        {editingId && (
          <button
            type="button"
            onClick={() => {
              setFormData({ title: '', content: '' });
              setEditingId(null);
            }}
          >
            Cancel
          </button>
        )}
      </form>

      <div className="data-list">
        <h2>Data Items</h2>
        {data.length === 0 ? (
          <p>No data available</p>
        ) : (
          <ul>
            {data.map((item) => (
              <li key={item.id} className="data-item">
                <h3>{item.title}</h3>
                <p>{item.content}</p>
                <div className="actions">
                  <button onClick={() => handleEdit(item)}>Edit</button>
                  <button onClick={() => handleDelete(item.id)}>Delete</button>
                </div>
              </li>
            ))}
          </ul>
        )}
      </div>
    </div>
  );
}

export default Dashboard;
