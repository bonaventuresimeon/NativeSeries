#!/usr/bin/env python3
"""
Test script for Netlify Function API
"""

import json
import sys
import os

# Add the current directory to Python path
sys.path.append(os.path.dirname(__file__))

from api import handler

def test_health_endpoint():
    """Test the health endpoint"""
    event = {
        'path': '/health',
        'httpMethod': 'GET',
        'headers': {},
        'queryStringParameters': None,
        'body': ''
    }
    
    result = handler(event, None)
    print(f"Health endpoint test: {result['statusCode']}")
    print(f"Response: {result['body']}")
    return result['statusCode'] == 200

def test_students_endpoint():
    """Test the students endpoint"""
    event = {
        'path': '/api/students',
        'httpMethod': 'GET',
        'headers': {},
        'queryStringParameters': None,
        'body': ''
    }
    
    result = handler(event, None)
    print(f"Students endpoint test: {result['statusCode']}")
    print(f"Response: {result['body']}")
    return result['statusCode'] == 200

def test_docs_endpoint():
    """Test the docs endpoint"""
    event = {
        'path': '/docs',
        'httpMethod': 'GET',
        'headers': {},
        'queryStringParameters': None,
        'body': ''
    }
    
    result = handler(event, None)
    print(f"Docs endpoint test: {result['statusCode']}")
    return result['statusCode'] == 200

if __name__ == "__main__":
    print("🧪 Testing Netlify Function API...")
    
    tests = [
        test_health_endpoint,
        test_students_endpoint,
        test_docs_endpoint
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        try:
            if test():
                passed += 1
                print("✅ Test passed")
            else:
                print("❌ Test failed")
        except Exception as e:
            print(f"❌ Test failed with error: {e}")
    
    print(f"\n📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All tests passed!")
        sys.exit(0)
    else:
        print("⚠️ Some tests failed")
        sys.exit(1)