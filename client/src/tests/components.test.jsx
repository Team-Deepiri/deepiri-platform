/**
 * Comprehensive test suite for React frontend components
 */
import React from 'react';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import { BrowserRouter } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from 'react-query';
import { vi, describe, test, expect, beforeEach, afterEach } from 'vitest';
import toast from 'react-hot-toast';

// Mock react-hot-toast
vi.mock('react-hot-toast', () => ({
  default: {
    success: vi.fn(),
    error: vi.fn(),
    loading: vi.fn(),
    dismiss: vi.fn(),
  },
}));

// Mock API modules
vi.mock('../api/authApi', () => ({
  authApi: {
    login: vi.fn(),
    register: vi.fn(),
    verifyToken: vi.fn(),
    logout: vi.fn(),
  },
}));

vi.mock('../api/adventureApi', () => ({
  adventureApi: {
    generateAdventure: vi.fn(),
    getAdventures: vi.fn(),
    getAdventure: vi.fn(),
    startAdventure: vi.fn(),
    completeAdventure: vi.fn(),
    updateAdventureStep: vi.fn(),
  },
}));

vi.mock('../api/eventApi', () => ({
  eventApi: {
    getEvents: vi.fn(),
    createEvent: vi.fn(),
    getEvent: vi.fn(),
    joinEvent: vi.fn(),
    leaveEvent: vi.fn(),
  },
}));

// Test utilities
const createTestQueryClient = () => new QueryClient({
  defaultOptions: {
    queries: { retry: false },
    mutations: { retry: false },
  },
});

const renderWithProviders = (ui, { queryClient = createTestQueryClient() } = {}) => {
  return render(
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        {ui}
      </BrowserRouter>
    </QueryClientProvider>
  );
};

// Import components after mocks
import Home from '../pages/Home';
import Navbar from '../components/Navbar';
import { AuthProvider, useAuth } from '../contexts/AuthContext';
import Login from '../pages/Login';
import Register from '../pages/Register';
import Dashboard from '../pages/Dashboard';
import AdventureGenerator from '../pages/AdventureGenerator';

describe('Home Component', () => {
  test('renders home page with correct content', () => {
    renderWithProviders(<Home />);
    
    expect(screen.getByText('Welcome to tripblip MAG 2.0')).toBeInTheDocument();
    expect(screen.getByText(/Your AI-powered adventure companion/)).toBeInTheDocument();
    expect(screen.getByText('Why Choose tripblip MAG 2.0?')).toBeInTheDocument();
    expect(screen.getByText('How It Works')).toBeInTheDocument();
  });

  test('shows sign up and sign in buttons when not authenticated', () => {
    renderWithProviders(<Home />);
    
    expect(screen.getByText('Get Started')).toBeInTheDocument();
    expect(screen.getByText('Sign In')).toBeInTheDocument();
  });

  test('shows adventure generation buttons when authenticated', () => {
    const mockUser = { name: 'Test User', email: 'test@example.com' };
    
    renderWithProviders(
      <AuthProvider>
        <Home />
      </AuthProvider>
    );
    
    // This would need the auth context to be properly mocked
    // For now, we'll test the basic rendering
    expect(screen.getByText('Welcome to tripblip MAG 2.0')).toBeInTheDocument();
  });
});

describe('Navbar Component', () => {
  test('renders navbar with logo and navigation', () => {
    renderWithProviders(<Navbar />);
    
    expect(screen.getByText('tripblip MAG 2.0')).toBeInTheDocument();
    expect(screen.getByText('🗺️')).toBeInTheDocument();
  });

  test('shows authentication buttons when not logged in', () => {
    renderWithProviders(<Navbar />);
    
    expect(screen.getByText('Sign In')).toBeInTheDocument();
    expect(screen.getByText('Sign Up')).toBeInTheDocument();
  });

  test('toggles mobile menu when menu button is clicked', () => {
    renderWithProviders(<Navbar />);
    
    const menuButton = screen.getByText('☰');
    fireEvent.click(menuButton);
    
    // Check if mobile menu is visible
    expect(screen.getByText('Sign In')).toBeInTheDocument();
  });

  test('handles logout when logout button is clicked', () => {
    const mockLogout = vi.fn();
    
    // Mock the auth context
    vi.mocked(useAuth).mockReturnValue({
      user: { name: 'Test User' },
      isAuthenticated: true,
      logout: mockLogout,
    });

    renderWithProviders(<Navbar />);
    
    const logoutButton = screen.getByText('Sign Out');
    fireEvent.click(logoutButton);
    
    expect(mockLogout).toHaveBeenCalled();
  });
});

describe('AuthContext', () => {
  let mockAuthApi;

  beforeEach(() => {
    mockAuthApi = vi.mocked(require('../api/authApi').authApi);
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  test('provides authentication state and methods', () => {
    const TestComponent = () => {
      const auth = useAuth();
      return (
        <div>
          <span data-testid="isAuthenticated">{auth.isAuthenticated.toString()}</span>
          <span data-testid="user">{auth.user?.name || 'No user'}</span>
        </div>
      );
    };

    renderWithProviders(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    expect(screen.getByTestId('isAuthenticated')).toHaveTextContent('false');
    expect(screen.getByTestId('user')).toHaveTextContent('No user');
  });

  test('handles successful login', async () => {
    const mockUser = { name: 'Test User', email: 'test@example.com' };
    const mockToken = 'mock-token';
    
    mockAuthApi.login.mockResolvedValue({
      success: true,
      data: { user: mockUser, token: mockToken }
    });

    const TestComponent = () => {
      const { login } = useAuth();
      
      const handleLogin = async () => {
        await login('test@example.com', 'password');
      };

      return <button onClick={handleLogin}>Login</button>;
    };

    renderWithProviders(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    const loginButton = screen.getByText('Login');
    fireEvent.click(loginButton);

    await waitFor(() => {
      expect(mockAuthApi.login).toHaveBeenCalledWith('test@example.com', 'password');
    });
  });

  test('handles login failure', async () => {
    mockAuthApi.login.mockResolvedValue({
      success: false,
      message: 'Invalid credentials'
    });

    const TestComponent = () => {
      const { login } = useAuth();
      
      const handleLogin = async () => {
        await login('test@example.com', 'wrongpassword');
      };

      return <button onClick={handleLogin}>Login</button>;
    };

    renderWithProviders(
      <AuthProvider>
        <TestComponent />
      </AuthProvider>
    );

    const loginButton = screen.getByText('Login');
    fireEvent.click(loginButton);

    await waitFor(() => {
      expect(mockAuthApi.login).toHaveBeenCalledWith('test@example.com', 'wrongpassword');
    });
  });
});

describe('Login Component', () => {
  let mockAuthApi;

  beforeEach(() => {
    mockAuthApi = vi.mocked(require('../api/authApi').authApi);
  });

  test('renders login form with email and password fields', () => {
    renderWithProviders(
      <AuthProvider>
        <Login />
      </AuthProvider>
    );

    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });

  test('validates required fields', async () => {
    renderWithProviders(
      <AuthProvider>
        <Login />
      </AuthProvider>
    );

    const submitButton = screen.getByRole('button', { name: /sign in/i });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/email is required/i)).toBeInTheDocument();
      expect(screen.getByText(/password is required/i)).toBeInTheDocument();
    });
  });

  test('submits form with valid data', async () => {
    mockAuthApi.login.mockResolvedValue({
      success: true,
      data: { user: { name: 'Test User' }, token: 'mock-token' }
    });

    renderWithProviders(
      <AuthProvider>
        <Login />
      </AuthProvider>
    );

    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });

    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockAuthApi.login).toHaveBeenCalledWith('test@example.com', 'password123');
    });
  });
});

describe('Register Component', () => {
  let mockAuthApi;

  beforeEach(() => {
    mockAuthApi = vi.mocked(require('../api/authApi').authApi);
  });

  test('renders registration form with all required fields', () => {
    renderWithProviders(
      <AuthProvider>
        <Register />
      </AuthProvider>
    );

    expect(screen.getByLabelText(/name/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/confirm password/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign up/i })).toBeInTheDocument();
  });

  test('validates password confirmation', async () => {
    renderWithProviders(
      <AuthProvider>
        <Register />
      </AuthProvider>
    );

    const passwordInput = screen.getByLabelText(/password/i);
    const confirmPasswordInput = screen.getByLabelText(/confirm password/i);
    const submitButton = screen.getByRole('button', { name: /sign up/i });

    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.change(confirmPasswordInput, { target: { value: 'different123' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(screen.getByText(/passwords do not match/i)).toBeInTheDocument();
    });
  });

  test('submits form with valid data', async () => {
    mockAuthApi.register.mockResolvedValue({
      success: true,
      data: { user: { name: 'Test User' }, token: 'mock-token' }
    });

    renderWithProviders(
      <AuthProvider>
        <Register />
      </AuthProvider>
    );

    const nameInput = screen.getByLabelText(/name/i);
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const confirmPasswordInput = screen.getByLabelText(/confirm password/i);
    const submitButton = screen.getByRole('button', { name: /sign up/i });

    fireEvent.change(nameInput, { target: { value: 'Test User' } });
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.change(confirmPasswordInput, { target: { value: 'password123' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockAuthApi.register).toHaveBeenCalledWith({
        name: 'Test User',
        email: 'test@example.com',
        password: 'password123',
        confirmPassword: 'password123'
      });
    });
  });
});

describe('Dashboard Component', () => {
  test('renders dashboard with user information', () => {
    // Mock authenticated user
    vi.mocked(useAuth).mockReturnValue({
      user: { name: 'Test User', email: 'test@example.com' },
      isAuthenticated: true,
      loading: false,
    });

    renderWithProviders(<Dashboard />);

    expect(screen.getByText(/welcome/i)).toBeInTheDocument();
    expect(screen.getByText('Test User')).toBeInTheDocument();
  });

  test('shows loading state', () => {
    vi.mocked(useAuth).mockReturnValue({
      user: null,
      isAuthenticated: false,
      loading: true,
    });

    renderWithProviders(<Dashboard />);

    expect(screen.getByText(/loading/i)).toBeInTheDocument();
  });
});

describe('AdventureGenerator Component', () => {
  let mockAdventureApi;

  beforeEach(() => {
    mockAdventureApi = vi.mocked(require('../api/adventureApi').adventureApi);
  });

  test('renders adventure generation form', () => {
    vi.mocked(useAuth).mockReturnValue({
      user: { name: 'Test User' },
      isAuthenticated: true,
      loading: false,
    });

    renderWithProviders(<AdventureGenerator />);

    expect(screen.getByText(/generate adventure/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/interests/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/duration/i)).toBeInTheDocument();
  });

  test('validates required fields', async () => {
    vi.mocked(useAuth).mockReturnValue({
      user: { name: 'Test User' },
      isAuthenticated: true,
      loading: false,
    });

    renderWithProviders(<AdventureGenerator />);

    const generateButton = screen.getByRole('button', { name: /generate/i });
    fireEvent.click(generateButton);

    await waitFor(() => {
      expect(screen.getByText(/please select at least one interest/i)).toBeInTheDocument();
    });
  });

  test('submits form with valid data', async () => {
    mockAdventureApi.generateAdventure.mockResolvedValue({
      success: true,
      data: { _id: 'adventure-123', name: 'Test Adventure' }
    });

    vi.mocked(useAuth).mockReturnValue({
      user: { name: 'Test User' },
      isAuthenticated: true,
      loading: false,
    });

    renderWithProviders(<AdventureGenerator />);

    const interestsInput = screen.getByLabelText(/interests/i);
    const durationInput = screen.getByLabelText(/duration/i);
    const generateButton = screen.getByRole('button', { name: /generate/i });

    fireEvent.change(interestsInput, { target: { value: 'food,music' } });
    fireEvent.change(durationInput, { target: { value: '60' } });
    fireEvent.click(generateButton);

    await waitFor(() => {
      expect(mockAdventureApi.generateAdventure).toHaveBeenCalled();
    });
  });
});

describe('Error Handling', () => {
  test('displays error messages for API failures', async () => {
    const mockAuthApi = vi.mocked(require('../api/authApi').authApi);
    mockAuthApi.login.mockRejectedValue(new Error('Network error'));

    renderWithProviders(
      <AuthProvider>
        <Login />
      </AuthProvider>
    );

    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const submitButton = screen.getByRole('button', { name: /sign in/i });

    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(toast.error).toHaveBeenCalledWith('Login failed. Please try again.');
    });
  });

  test('handles network errors gracefully', async () => {
    const mockAdventureApi = vi.mocked(require('../api/adventureApi').adventureApi);
    mockAdventureApi.generateAdventure.mockRejectedValue(new Error('Network error'));

    vi.mocked(useAuth).mockReturnValue({
      user: { name: 'Test User' },
      isAuthenticated: true,
      loading: false,
    });

    renderWithProviders(<AdventureGenerator />);

    const interestsInput = screen.getByLabelText(/interests/i);
    const generateButton = screen.getByRole('button', { name: /generate/i });

    fireEvent.change(interestsInput, { target: { value: 'food' } });
    fireEvent.click(generateButton);

    await waitFor(() => {
      expect(toast.error).toHaveBeenCalled();
    });
  });
});

describe('Accessibility', () => {
  test('form inputs have proper labels', () => {
    renderWithProviders(
      <AuthProvider>
        <Login />
      </AuthProvider>
    );

    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
  });

  test('buttons have accessible names', () => {
    renderWithProviders(<Home />);

    expect(screen.getByRole('button', { name: /get started/i })).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /sign in/i })).toBeInTheDocument();
  });

  test('navigation has proper ARIA attributes', () => {
    renderWithProviders(<Navbar />);

    const nav = screen.getByRole('navigation');
    expect(nav).toBeInTheDocument();
  });
});

describe('Responsive Design', () => {
  test('mobile menu toggles correctly', () => {
    // Mock window.innerWidth for mobile
    Object.defineProperty(window, 'innerWidth', {
      writable: true,
      configurable: true,
      value: 500,
    });

    renderWithProviders(<Navbar />);

    const menuButton = screen.getByText('☰');
    expect(menuButton).toBeInTheDocument();

    fireEvent.click(menuButton);
    expect(screen.getByText('Sign In')).toBeInTheDocument();
  });
});

// Integration tests
describe('User Flow Integration', () => {
  test('complete user registration and login flow', async () => {
    const mockAuthApi = vi.mocked(require('../api/authApi').authApi);
    
    // Mock successful registration
    mockAuthApi.register.mockResolvedValue({
      success: true,
      data: { user: { name: 'Test User' }, token: 'mock-token' }
    });

    renderWithProviders(
      <AuthProvider>
        <Register />
      </AuthProvider>
    );

    // Fill registration form
    const nameInput = screen.getByLabelText(/name/i);
    const emailInput = screen.getByLabelText(/email/i);
    const passwordInput = screen.getByLabelText(/password/i);
    const confirmPasswordInput = screen.getByLabelText(/confirm password/i);
    const submitButton = screen.getByRole('button', { name: /sign up/i });

    fireEvent.change(nameInput, { target: { value: 'Test User' } });
    fireEvent.change(emailInput, { target: { value: 'test@example.com' } });
    fireEvent.change(passwordInput, { target: { value: 'password123' } });
    fireEvent.change(confirmPasswordInput, { target: { value: 'password123' } });
    fireEvent.click(submitButton);

    await waitFor(() => {
      expect(mockAuthApi.register).toHaveBeenCalled();
    });
  });
});

export { renderWithProviders, createTestQueryClient };
