from locust import HttpUser, task, constant

class TaskManagerLoadTest(HttpUser):
    wait_time = constant(0)

    @task(1)
    def hit_api_root(self):
        """Tests the base api gateway route (Reduced weight)."""
        self.client.get("/", name="01_API_Gateway_Root")

    @task(2)
    def simulate_task_fetching(self):
        """Simulates heavy database read stress on the task endpoint."""
        self.client.get("/api/tasks", name="02_Get_Tasks_Endpoint")

    
    @task(10)
    def simulate_auth_load(self):
        """Simulates compute-heavy password hashing/checking requests."""
        payload = {
            "email": "load_test_user@mail.com",
            "password": "securepassword123"
        }
        self.client.post("/api/auth", json=payload, name="03_Post_Auth_Endpoint")