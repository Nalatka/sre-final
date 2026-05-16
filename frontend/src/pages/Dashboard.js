import React, { useState, useEffect, useCallback } from 'react';
import Navbar from '../components/Navbar';
import { taskService } from '../services/api';
import { toast } from 'react-toastify';
import { format } from 'date-fns';

const Dashboard = () => {
  const [tasks, setTasks] = useState([]);
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editingTask, setEditingTask] = useState(null);
  const [filters, setFilters] = useState({
    status: '',
    priority: '',
    sort: 'createdAt'
  });
  const [formData, setFormData] = useState({
    title: '',
    description: '',
    status: 'pending',
    dueDate: '',
    priority: 'medium',
    tags: []
  });

  const fetchTasks = useCallback(async () => {
    try {
      const response = await taskService.getTasks(filters);
      setTasks(response.data.tasks);
    } catch (error) {
      toast.error('Failed to fetch tasks');
    } finally {
      setLoading(false);
    }
  }, [filters]);

  const fetchStats = useCallback(async () => {
    try {
      const response = await taskService.getTaskStats();
      setStats(response.data.stats);
    } catch (error) {
      console.error('Failed to fetch stats');
    }
  }, []);

  useEffect(() => {
    fetchTasks();
    fetchStats();
  }, [fetchTasks, fetchStats]);

  const handleFilterChange = (e) => {
    setFilters({
      ...filters,
      [e.target.name]: e.target.value
    });
  };

  const handleInputChange = (e) => {
    setFormData({
      ...formData,
      [e.target.name]: e.target.value
    });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    try {
      if (editingTask) {
        await taskService.updateTask(editingTask._id, formData);
        toast.success('Task updated successfully');
      } else {
        await taskService.createTask(formData);
        toast.success('Task created successfully');
      }
      setShowModal(false);
      resetForm();
      fetchTasks();
      fetchStats();
    } catch (error) {
      toast.error(error.response?.data?.message || 'Operation failed');
    }
  };

  const handleEdit = (task) => {
    setEditingTask(task);
    setFormData({
      title: task.title,
      description: task.description || '',
      status: task.status,
      dueDate: format(new Date(task.dueDate), 'yyyy-MM-dd'),
      priority: task.priority,
      tags: task.tags || []
    });
    setShowModal(true);
  };

  const handleDelete = async (id) => {
    if (window.confirm('Are you sure you want to delete this task?')) {
      try {
        await taskService.deleteTask(id);
        toast.success('Task deleted successfully');
        fetchTasks();
        fetchStats();
      } catch (error) {
        toast.error('Failed to delete task');
      }
    }
  };

  const resetForm = () => {
    setFormData({
      title: '',
      description: '',
      status: 'pending',
      dueDate: '',
      priority: 'medium',
      tags: []
    });
    setEditingTask(null);
  };

  const handleNewTask = () => {
    resetForm();
    setShowModal(true);
  };

  if (loading) {
    return <div className="loading">Loading...</div>;
  }

  return (
    <>
      <Navbar />
      <div className="container">
        <div className="dashboard-header">
          <h1>My Tasks</h1>
          <p>Manage and organize your tasks efficiently</p>
        </div>

        {stats && (
          <div className="stats-grid">
            <div className="stat-card">
              <h3>Total Tasks</h3>
              <div className="stat-value">{stats.total}</div>
            </div>
            <div className="stat-card">
              <h3>Pending</h3>
              <div className="stat-value">{stats.byStatus?.pending || 0}</div>
            </div>
            <div className="stat-card">
              <h3>In Progress</h3>
              <div className="stat-value">{stats.byStatus?.['in-progress'] || 0}</div>
            </div>
            <div className="stat-card">
              <h3>Completed</h3>
              <div className="stat-value">{stats.byStatus?.completed || 0}</div>
            </div>
            <div className="stat-card">
              <h3>Overdue</h3>
              <div className="stat-value" style={{color: '#ef4444'}}>{stats.overdue}</div>
            </div>
          </div>
        )}

        <div className="tasks-section">
          <div className="section-header">
            <h2>Tasks</h2>
            <button className="btn btn-primary" onClick={handleNewTask}>
              + New Task
            </button>
          </div>

          <div className="filters">
            <select name="status" value={filters.status} onChange={handleFilterChange}>
              <option value="">All Status</option>
              <option value="pending">Pending</option>
              <option value="in-progress">In Progress</option>
              <option value="completed">Completed</option>
            </select>
            <select name="priority" value={filters.priority} onChange={handleFilterChange}>
              <option value="">All Priorities</option>
              <option value="high">High</option>
              <option value="medium">Medium</option>
              <option value="low">Low</option>
            </select>
            <select name="sort" value={filters.sort} onChange={handleFilterChange}>
              <option value="createdAt">Sort by Date</option>
              <option value="dueDate">Sort by Due Date</option>
              <option value="priority">Sort by Priority</option>
            </select>
          </div>

          {tasks.length === 0 ? (
            <div className="empty-state">
              <p>No tasks found. Create your first task!</p>
            </div>
          ) : (
            <div className="task-list">
              {tasks.map((task) => (
                <div key={task._id} className="task-card">
                  <div className="task-header">
                    <div>
                      <div className="task-title">{task.title}</div>
                      {task.description && <p style={{color: '#666', marginTop: '5px'}}>{task.description}</p>}
                    </div>
                  </div>
                  <div className="task-meta">
                    <span className="badge badge-status">{task.status}</span>
                    <span className={`badge badge-priority-${task.priority}`}>{task.priority}</span>
                    <span style={{color: '#666', fontSize: '14px'}}>
                      Due: {format(new Date(task.dueDate), 'MMM dd, yyyy')}
                    </span>
                  </div>
                  <div className="task-actions">
                    <button className="btn-small btn-secondary" onClick={() => handleEdit(task)}>
                      Edit
                    </button>
                    <button className="btn-small btn-danger" onClick={() => handleDelete(task._id)}>
                      Delete
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </div>

        {showModal && (
          <div className="modal-overlay" onClick={() => setShowModal(false)}>
            <div className="modal" onClick={(e) => e.stopPropagation()}>
              <h2>{editingTask ? 'Edit Task' : 'Create New Task'}</h2>
              <form onSubmit={handleSubmit}>
                <div className="form-group">
                  <label>Title</label>
                  <input
                    type="text"
                    name="title"
                    value={formData.title}
                    onChange={handleInputChange}
                    required
                    placeholder="Task title"
                  />
                </div>
                <div className="form-group">
                  <label>Description</label>
                  <textarea
                    name="description"
                    value={formData.description}
                    onChange={handleInputChange}
                    rows="3"
                    placeholder="Task description"
                    style={{width: '100%', padding: '12px', border: '1px solid #ddd', borderRadius: '5px'}}
                  />
                </div>
                <div className="form-group">
                  <label>Status</label>
                  <select name="status" value={formData.status} onChange={handleInputChange}>
                    <option value="pending">Pending</option>
                    <option value="in-progress">In Progress</option>
                    <option value="completed">Completed</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Priority</label>
                  <select name="priority" value={formData.priority} onChange={handleInputChange}>
                    <option value="low">Low</option>
                    <option value="medium">Medium</option>
                    <option value="high">High</option>
                  </select>
                </div>
                <div className="form-group">
                  <label>Due Date</label>
                  <input
                    type="date"
                    name="dueDate"
                    value={formData.dueDate}
                    onChange={handleInputChange}
                    required
                  />
                </div>
                <div className="modal-actions">
                  <button type="submit" className="btn btn-primary">
                    {editingTask ? 'Update' : 'Create'}
                  </button>
                  <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>
                    Cancel
                  </button>
                </div>
              </form>
            </div>
          </div>
        )}
      </div>
    </>
  );
};

export default Dashboard;
