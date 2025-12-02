import os
import sys
from airflow.utils.session import create_session

def create_admin_user():
    try:
        # Try importing from FAB provider (Airflow 3.x with FAB decoupled)
        from airflow.providers.fab.auth_manager.security_manager.override import FabAirflowSecurityManagerOverride
        from airflow.providers.fab.auth_manager.models import User, Role
        security_manager_class = FabAirflowSecurityManagerOverride
    except ImportError:
        try:
            # Fallback to Airflow 2.x style or bundled FAB
            from airflow.www.security import ApplessAirflowSecurityManager
            security_manager_class = ApplessAirflowSecurityManager
        except ImportError:
            print("Could not import Security Manager. FAB provider might be missing.")
            sys.exit(1)

    username = os.environ.get('AIRFLOW_ADMIN_USERNAME', 'admin')
    email = os.environ.get('AIRFLOW_ADMIN_EMAIL', 'admin@example.com')
    password = os.environ.get('AIRFLOW_ADMIN_PASSWORD', 'admin')
    
    print(f"Creating user {username}...")
    
    with create_session() as session:
        security_manager = security_manager_class(session=session)
        role = security_manager.find_role('Admin')
        if not role:
            print("Admin role not found!")
            # Try to create it or sync roles?
            # security_manager.sync_roles()
            return

        user = security_manager.find_user(username=username)
        if user:
            print(f"User {username} already exists")
            return
            
        user = security_manager.add_user(
            username=username,
            firstname='Admin',
            lastname='User',
            email=email,
            role=role,
            password=password
        )
        if user:
            print(f"User {username} created successfully")
        else:
            print(f"Failed to create user {username}")

if __name__ == "__main__":
    try:
        create_admin_user()
    except Exception as e:
        print(f"Error creating user: {e}")
        sys.exit(1)
