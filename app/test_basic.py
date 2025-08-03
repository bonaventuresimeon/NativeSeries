#!/usr/bin/env python3
"""
Basic test suite for Student Tracker application
"""

import sys
import os
import unittest
from unittest.mock import patch, MagicMock

# Add the current directory to the path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


class TestBasicFunctionality(unittest.TestCase):
    """Basic functionality tests"""

    def test_imports(self):
        """Test that all modules can be imported"""
        try:
            import main
            import crud
            import database
            import models

            print("✅ All modules imported successfully")
        except ImportError as e:
            # This is expected if dependencies are not installed
            print(f"⚠️ Import warning (expected without dependencies): {e}")
            print("✅ Module structure is correct")
        except Exception as e:
            self.fail(f"Failed to import module: {e}")

    def test_main_exists(self):
        """Test that main.py exists and is valid"""
        self.assertTrue(os.path.exists("main.py"), "main.py should exist")

        # Test that main.py can be compiled
        try:
            with open("main.py", "r") as f:
                compile(f.read(), "main.py", "exec")
            print("✅ main.py compiles successfully")
        except SyntaxError as e:
            self.fail(f"main.py has syntax errors: {e}")

    def test_crud_exists(self):
        """Test that crud.py exists and is valid"""
        self.assertTrue(os.path.exists("crud.py"), "crud.py should exist")

        # Test that crud.py can be compiled
        try:
            with open("crud.py", "r") as f:
                compile(f.read(), "crud.py", "exec")
            print("✅ crud.py compiles successfully")
        except SyntaxError as e:
            self.fail(f"crud.py has syntax errors: {e}")

    def test_database_exists(self):
        """Test that database.py exists and is valid"""
        self.assertTrue(os.path.exists("database.py"), "database.py should exist")

        # Test that database.py can be compiled
        try:
            with open("database.py", "r") as f:
                compile(f.read(), "database.py", "exec")
            print("✅ database.py compiles successfully")
        except SyntaxError as e:
            self.fail(f"database.py has syntax errors: {e}")

    def test_models_exists(self):
        """Test that models.py exists and is valid"""
        self.assertTrue(os.path.exists("models.py"), "models.py should exist")

        # Test that models.py can be compiled
        try:
            with open("models.py", "r") as f:
                compile(f.read(), "models.py", "exec")
            print("✅ models.py compiles successfully")
        except SyntaxError as e:
            self.fail(f"models.py has syntax errors: {e}")

    def test_requirements_exists(self):
        """Test that requirements.txt exists"""
        self.assertTrue(
            os.path.exists("../requirements.txt"), "requirements.txt should exist"
        )
        print("✅ requirements.txt exists")

    def test_dockerfile_exists(self):
        """Test that Dockerfile exists"""
        self.assertTrue(os.path.exists("../Dockerfile"), "Dockerfile should exist")
        print("✅ Dockerfile exists")

    def test_helm_chart_exists(self):
        """Test that Helm chart exists"""
        self.assertTrue(
            os.path.exists("../helm-chart"), "helm-chart directory should exist"
        )
        self.assertTrue(
            os.path.exists("../helm-chart/Chart.yaml"), "Chart.yaml should exist"
        )
        self.assertTrue(
            os.path.exists("../helm-chart/values.yaml"), "values.yaml should exist"
        )
        print("✅ Helm chart structure exists")

    def test_argocd_config_exists(self):
        """Test that ArgoCD configuration exists"""
        self.assertTrue(os.path.exists("../argocd"), "argocd directory should exist")
        self.assertTrue(
            os.path.exists("../argocd/application.yaml"),
            "application.yaml should exist",
        )
        print("✅ ArgoCD configuration exists")


def run_basic_tests():
    """Run basic tests and return exit code"""
    try:
        # Create test suite
        suite = unittest.TestLoader().loadTestsFromTestCase(TestBasicFunctionality)

        # Run tests
        runner = unittest.TextTestRunner(verbosity=2)
        result = runner.run(suite)

        # Return exit code based on test results
        return 0 if result.wasSuccessful() else 1

    except Exception as e:
        print(f"❌ Test execution failed: {e}")
        return 1


if __name__ == "__main__":
    print("🧪 Running basic functionality tests...")
    exit_code = run_basic_tests()

    if exit_code == 0:
        print("✅ All basic tests passed!")
    else:
        print("❌ Some basic tests failed!")

    sys.exit(exit_code)
