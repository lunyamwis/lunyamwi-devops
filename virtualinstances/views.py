# # views.py
# import os
# import time
# import subprocess
# from django.conf import settings
# from rest_framework.views import APIView
# from rest_framework.response import Response
# from rest_framework import status
# from .serializers import CreateVMRequestSerializer
# from googleapiclient import discovery
# from google.oauth2 import service_account
# import paramiko

# class CreateVMAndRunDockerAPIView(APIView):
#     compute = None  # Class attribute for the compute object
#     computev1 = None  # Class attribute for the compute object

#     def authenticate_with_google_cloud(self):
#         key_path = os.path.join(settings.BASE_DIR, 'boostedchatapi-serviceaccount.json')
#         credentials = service_account.Credentials.from_service_account_file(
#             key_path,
#             scopes=['https://www.googleapis.com/auth/cloud-platform'],
#         )
#         project_id = 'boostedchatapi'
#         zone = 'us-central1-a'

#         self.compute = discovery.build('compute', 'v1', credentials=credentials)
#         # try:
#         #     self.create_ssh_firewall_rule(project_id, "firewall-rules")
#         # except Exception as error:
#         #     print(f"An error occurred: {error}")
#         #     print("Firewall rule already exists")

#         return project_id, zone

#     def create_ssh_firewall_rule(self, project_id, rule_name='allow-ssh'):
#         # firewall_body = {
#         #     'name': rule_name,
#         #     'network': 'global/networks/default',
#         #     'direction': 'INGRESS',
#         #     'priority': 1000,
#         #     'sourceRanges': ['0.0.0.0/0'],
#         #     'allowed': [
#         #         {"IPProtocol": "tcp", "ports": ["22"]},  # Allow SSH traffic
#         #         {"IPProtocol": "tcp", "ports": ["80"]},  # Allow HTTP traffic
#         #         {"IPProtocol": "tcp", "ports": ["443"]}  # Allow HTTPS traffic
#         #     #     {
#         #     #     'IPProtocol': 'tcp',
#         #     #     'ports': ['22'],
#         #     # }
#         #     ],
#         #     'targetTags': [rule_name],
#         # }

#         # request = self.compute.firewalls().insert(project=project_id, body=firewall_body)
#         # response = request.execute()
#         # print(f"Firewall rule {rule_name} created: {response}")
#         # Create firewall rules for HTTP, HTTPS, and load balancer health checks
#         http_firewall_rule = {
#             'name': 'allow-http',
#             'direction': 'INGRESS',
#             'priority': 1000,
#             'action': 'ALLOW',
#             'allowed': [{
#                 'IPProtocol': 'tcp',
#                 'ports': ['80']
#             }],
#             'sourceRanges': ['0.0.0.0/0'],
#             'targetTags': ['allow-http']
#         }
#         https_firewall_rule = {
#             'name': 'allow-https',
#             'direction': 'INGRESS',
#             'priority': 1000,
#             'action': 'ALLOW',
#             'allowed': [{
#                 'IPProtocol': 'tcp',
#                 'ports': ['443']
#             }],
#             'sourceRanges': ['0.0.0.0/0'],
#             'targetTags': ['allow-https']
#         }
#         health_check_firewall_rule = {
#             'name': 'allow-health-checks',
#             'direction': 'INGRESS',
#             'priority': 1000,
#             'action': 'ALLOW',
#             'allowed': [{
#                 'IPProtocol': 'tcp',
#                 'ports': ['80', '443']  # Adjust ports as necessary for health checks
#             }],
#             'sourceRanges': ['130.211.0.0/22', '35.191.0.0/16'],  # Google health check ranges
#             'targetTags': ['lb-health-check']
#         }

#         self.compute.firewalls().insert(project=project_id, body=http_firewall_rule).execute()
#         self.compute.firewalls().insert(project=project_id, body=https_firewall_rule).execute()
#         self.compute.firewalls().insert(project=project_id, body=health_check_firewall_rule).execute()

#     def create_vm(self, project_id, zone, vm_instance_name):
#         vm_name = vm_instance_name
#         machine_type = 'n2-standard-2'
#         image_project = 'ubuntu-os-cloud'
#         image_family = 'ubuntu-2204-jammy-v20240110'

#         request_body = {
#             'name': vm_name,
#             'machineType': f'zones/{zone}/machineTypes/{machine_type}',
#             'disks': [{
#                 'boot': True,
#                 'initializeParams': {
#                     'sourceImage': f'projects/{image_project}/global/images/{image_family}',
#                     'diskSizeGb': '25' 
#                 }
#             }],
#             'networkInterfaces': [{
#                 'network': 'global/networks/default',
#                 'accessConfigs': [{
#                     'type': 'ONE_TO_ONE_NAT',
#                     'name': 'External NAT'
#                 }],
#                 # 'tags': ['allow-ssh','allow80','http-server','https-server','lb-health-check',]  # Add the target tags here
#             }],
#             'tags': {
#                     'items': ['allow-ssh','allow80','http-server','https-server','lb-health-check',]
#             }
#         }

#         # response = self.compute.instances().insert(project=project_id, zone=zone, body=request_body).execute()
#         try:
#             response = self.compute.instances().insert(project=project_id, zone=zone, body=request_body).execute()
#             print(response)
#             print("VM instance created successfully.")
#              # Extract and return the IP address of the new VM
#             vm_ip = None
#             time.sleep(20)
#             instance_name = response.get('targetLink', '').split('/')[-1]

#             if instance_name:
#                 # Fetch details of the newly created instance to get the IP address
#                 instance = self.compute.instances().get(project=project_id, zone=zone, instance=instance_name).execute()

#                 # Extract the IP address from the instance details
#                 network_interfaces = instance.get('networkInterfaces', [])
#                 if network_interfaces:
#                     access_configs = network_interfaces[0].get('accessConfigs', [])
#                     if access_configs:
#                         vm_ip = access_configs[0].get('natIP', None)
#                         if vm_ip:
#                             # Use vm_ip as needed
#                             print(f"VM IP Address: {vm_ip}")
#                         else:
#                             print("Unable to retrieve VM IP address (natIP is None)")
#                     else:
#                         print("No 'accessConfigs' in 'networkInterfaces'")
#                 else:
#                     print("No 'networkInterfaces' in instance details")
#             else:
#                 print("Unable to extract instance name from operation response")

#             return vm_ip, instance_name
#         except Exception as e:
#             print(f"Failed to create VM instance: {str(e)}")

       

    

#     def ssh_key(self, ttl, project_id, ssh_key_path):
#         print(ssh_key_path)
#         # ssh_key_command = [
#         #     'gcloud',
#         #     'compute',
#         #     'os-login',
#         #     'ssh-keys',
#         #     'add',
#         #     f'--ttl={ttl}',
#         #     f'--project={project_id}',
#         #     f'--key-file={ssh_key_path}',
#         #     '--quiet'
#         # ]

#         # try:
#         #     subprocess.run(ssh_key_command, check=True)
#         #     print(f"successfully.")
#         # except subprocess.CalledProcessError as e:
#         #     print(f"Error: {e}")
    
#     # def scp_to_vm(self, vm_name, username, zone, project_id, ssh_key_path, local_file_path, remote_vm_path):
#     #     scp_command = [
#     #         'gcloud',
#     #         'compute',
#     #         'scp',
#     #         f'--zone={zone}',
#     #         f'--project={project_id}',
#     #         f'--ssh-key-file={ssh_key_path}',
#     #         f'{local_file_path}',
#     #         f'{username}@{vm_name}:{remote_vm_path}',
#     #     ]

#     #     try:
#     #         subprocess.run(scp_command, check=True)
#     #         print(f"File '{local_file_path}' copied to VM '{vm_name}' at '{remote_vm_path}' successfully.")
#     #     except subprocess.CalledProcessError as e:
#     #         print(f"Error: {e}")


    
#     # def write_to_env_file_remote(self, server_address, username, private_key_path, file_path, key_value_pairs):
#     #     """
#     #     Write key-value pairs to a .env file on a remote server using paramiko.

#     #     Parameters:
#     #     - server_address (str): IP address or hostname of the remote server.
#     #     - username (str): SSH username.
#     #     - private_key_path (str): Path to the private key file for SSH authentication.
#     #     - file_path (str): Path to the .env file on the remote server.
#     #     - key_value_pairs (dict): Dictionary containing key-value pairs.

#     #     Example:
#     #     write_to_env_file_remote('your_server_ip', 'your_username', '/path/to/private/key', '/path/to/.env', {'KEY1': 'value1', 'KEY2': 'value2'})
#     #     """
#     #     try:
#     #         # Create an SSH client
#     #         ssh = paramiko.SSHClient()
#     #         ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

#     #         # Connect to the server using private key authentication
#     #         ssh.connect(server_address, username=username, key_filename=private_key_path)

#     #         # Create a temporary local .env file
#     #         local_temp_env_file_path = 'temp_env_file'
#     #         with open(local_temp_env_file_path, 'w') as local_env_file:
#     #             for key, value in key_value_pairs.items():
#     #                 local_env_file.write(f"{key}={value}\n")

#     #         # Upload the local .env file to the remote server
#     #         sftp = ssh.open_sftp()
#     #         sftp.put(local_temp_env_file_path, file_path)
#     #         sftp.close()

#     #         print(f"Successfully wrote to {file_path} on the remote server")

#     #     except Exception as e:
#     #         print(f"Error writing to {file_path} on the remote server: {e}")

#     #     finally:
#     #         # Close the SSH connection
#     #         ssh.close()

#     def upload_install_script_and_execute(self, ssh, env):

#         try:
#             print("mkdir -p /etc/boostedchat/")
#             _, _, _ = ssh.exec_command("mkdir -p /etc/boostedchat/")
#             # Upload install.sh
#             sftp = ssh.open_sftp()
#             print("copying files")
#             sftp.put("install.sh", "/root/install.sh")
#             sftp.put("/etc/boostedchat/.env", "/etc/boostedchat/.env") # assumes file is already in /etc/boostedchat/.env
#             sftp.put("/home/boostedchat/.ssh/boostedchat-site.pem", "/root/.ssh/id_rsa_git") # assumes "/home/boostedchat/.ssh/boostedchat-site.pem" already exists
#             sftp.close()
            
#             print("chmod +x /root/install.sh")
#             _, _, _ = ssh.exec_command("chmod +x /root/install.sh")

#             # Execute install.sh
#             print("cd /root/ && bash ./install.sh")
#             _, stdout, stderr = ssh.exec_command(f"cd /root/ && bash ./install.sh {env}")

#             # Read output and error (if any)
#             output = stdout.read().decode("utf-8")
#             error = stderr.read().decode("utf-8")

#             if output:
#                 print("Output:", output)
#             if error:
#                 print("Error:", error)

#             return True
#         except Exception as e:
#             print(f"Error copying install.sh to the remote server: {e}")
    
#     def copy_file_to_server(self, compute_client, project_id, zone, vm_name, source_path, dest_path):
#         try:
#             operation = compute_client.instances.copy_files(
#                 project=project_id,
#                 zone=zone,
#                 instance=vm_name,
#                 source=source_path,
#                 destination=dest_path
#             )
#             operation.result()  # Wait for the operation to complete
#             print(f"Files copied to {vm_name} successfully")
#             return True
#         except Exception as error:
#             print("Error copying files to the server:", error)
#             return
#     def run_commands_on_server(self, compute_client, project_id, zone, vm_name, commands):
#         try:
#             response = compute_client.instances.start_with_encryption_key(
#                 project=project_id,
#                 zone=zone,
#                 instance=vm_name,
#                 body={"commands": commands},
#             ).execute()
#             print("Commands executed on the server:", response)
#             return True
#         except Exception as error:
#             print("Error executing commands on the server:", error)
    
#     def connect_to_vm_via_gcloud(self, compute_client, project_id, zone, vm_name):
#         # Copy files to the server
#         print("running mkdir -p /etc/boostedchat/")
#         self.run_commands_on_server(compute_client, project_id, zone, vm_name, ["mkdir -p /etc/boostedchat/"])
#         print("copying files to server/")
#         self.copy_file_to_server(compute_client, project_id, zone, vm_name, "install.sh", "/root/install.sh")
#         self.copy_file_to_server(compute_client, project_id, zone, vm_name, "/etc/boostedchat/.env", "/etc/boostedchat/.env")
#         print("Running install.sh")
#         self.run_commands_on_server(compute_client, project_id, zone, vm_name, ["chmod +x /root/install.sh", "cd /root/ && ./install.sh"])

#         # Run commands on the server
        
            
#     def connect_to_vm_via_ssh(self, vm_ip, ssh_key_path, vm_username, env):
#         time.sleep(20)
#         try:
#             self.ssh_key('5d','boostedchatapi', 
#             ssh_key_path)
#         except Exception as err:
#             print(f"=========={err}")

#         time.sleep(5)
        
#         # Connect to VM via SSH using paramiko
#         print("waiting 20 secs")
#         try:
#             ssh = paramiko.SSHClient()
#             ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
#             private_key = paramiko.RSAKey(filename=ssh_key_path)
#             ssh.connect(vm_ip, username=vm_username, pkey=private_key)
#             print("upload_install_script_and_execute")
#             self.upload_install_script_and_execute(ssh, env)
        
#             ssh.close()

#         except Exception as err:
#             print(f"Error connecting to VM: {err}")
#         finally:
#             if ssh:
#                 ssh.close()
#     def setup_subdomains_automatically(self, ip, subdomain):
#         import requests
        
#         subdomains = [
#             f"{subdomain}",
#             f"airflow.{subdomain}",
#             f"api.{subdomain}",
#             f"promptemplate.{subdomain}",
#             f"scrapper.{subdomain}",

#         ]

#         # Cloudflare API endpoint for creating DNS records
#         url = f"https://api.cloudflare.com/client/v4/zones/{os.environ.get('CLOUDFLARE_ZONE_ID')}/dns_records"

#         # Replace YOUR_API_TOKEN and YOUR_ZONE_ID with your actual Cloudflare API token and zone ID
#         headers = {
#             "Authorization": f"Bearer {os.environ.get('CLOUDFLARE_API_TOKEN')}",
#             "Content-Type": "application/json",
#         }
#         # Iterate over each URL and make a POST request to create the DNS record
#         for subdomain_item in subdomains:
#             # DNS record details
#             dns_record_data = {
#                 "type": "A",              # DNS record type (e.g., A, CNAME, MX, etc.)
#                 "name": subdomain_item,   # Name of the DNS record (e.g., subdomain)
#                 "content": ip,            # Value of the DNS record (e.g., IP address)
#                 "ttl": 120,               # Time to Live in seconds (optional)
#                 "proxied": False          # Whether the record is proxied through Cloudflare (True/False)
#             }

#             # Make the POST request to create the DNS record
#             response = requests.post(url, headers=headers, json=dns_record_data)

#             # Check the response status
#             if response.status_code == 200:
#                 created_record = response.json()["result"]
#                 print(f"DNS record created successfully for {subdomain_item}: ID {created_record['id']}")
#             else:
#                 print(f"Failed to create DNS record for {subdomain_item}. Status code: {response.status_code}")
#                 print(response.text)
    
#     def post(self, request, *args, **kwargs):
#         # Validate input data
#         print("starting")
#         serializer = CreateVMRequestSerializer(data=request.data)
#         if serializer.is_valid():
#             # Authentication
#             print("authenticating with gcloud")
#             project_id, zone = self.authenticate_with_google_cloud()

#             # Create VM
#             vm_name = request.data.get("company_name")
#             env = request.data.get("env")
#             vm_ip,_ = self.create_vm(project_id, zone, vm_name)

#             # Connect to VM via SSH
#             default_ssh_key_path = "/home/boostedchat/.ssh/key.pem"
#             ssh_key_path = os.path.join(settings.BASE_DIR, 'key.pem')

#             if not os.path.exists(ssh_key_path):
#                 ssh_key_path = default_ssh_key_path

#             print(ssh_key_path)
#             vm_username = 'root'

#             self.setup_subdomains_automatically(vm_ip, vm_name)
#             # self.connect_to_vm_via_gcloud(compute_client, project_id, zone, vm_name)
#             print("connect_to_vm_via_ssh")
#             self.connect_to_vm_via_ssh(vm_ip, ssh_key_path, vm_username, env)

#             return Response({'status': 'success', 'vm_ip': vm_ip}, status=status.HTTP_200_OK)

#         else:
#             return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
# views.py
import os
import time
import subprocess
from django.conf import settings
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from .serializers import CreateVMRequestSerializer
from googleapiclient import discovery
from google.oauth2 import service_account
import paramiko

class CreateVMAndRunDockerAPIView(APIView):
    compute = None  # Class attribute for the compute object
    computev1 = None  # Class attribute for the compute object

    def authenticate_with_google_cloud(self):
        key_path = os.path.join(settings.BASE_DIR, 'boostedchatapi-serviceaccount.json')
        credentials = service_account.Credentials.from_service_account_file(
            key_path,
            scopes=['https://www.googleapis.com/auth/cloud-platform'],
        )
        project_id = 'boostedchatapi'
        zone = 'us-central1-a'

        self.compute = discovery.build('compute', 'v1', credentials=credentials)
        try:
            self.create_ssh_firewall_rule(project_id, "allow https")
            self.create_ssh_firewall_rule(project_id)
        except Exception as error:
            print("firewall rule already exists")

        return project_id, zone

    def create_ssh_firewall_rule(self, project_id, rule_name='allow-ssh'):
        firewall_body = {
            'name': rule_name,
            'network': 'global/networks/default',
            'direction': 'INGRESS',
            'priority': 1000,
            'sourceRanges': ['0.0.0.0/0'],
            'allowed': [{
                'IPProtocol': 'tcp',
                'ports': ['22'],
            }],
            'targetTags': [rule_name],
        }

        request = self.compute.firewalls().insert(project=project_id, body=firewall_body)
        response = request.execute()
        print(f"Firewall rule {rule_name} created: {response}")

    def create_vm(self, project_id, zone, vm_instance_name):
        vm_name = vm_instance_name
        machine_type = 'n2-standard-2'
        image_project = 'ubuntu-os-cloud'
        image_family = 'ubuntu-2204-jammy-v20240110'

        request_body = {
            'name': vm_name,
            'machineType': f'zones/{zone}/machineTypes/{machine_type}',
            'disks': [{
                'boot': True,
                'initializeParams': {
                    'sourceImage': f'projects/{image_project}/global/images/{image_family}'
                }
            }],
            'networkInterfaces': [{
                'network': 'global/networks/default',
                'accessConfigs': [{
                    'type': 'ONE_TO_ONE_NAT',
                    'name': 'External NAT'
                }],
                'tags': ['allow-ssh','allow80','http-server','https-server','lb-health-check',]  # Add the target tags here
            }]
        }

        response = self.compute.instances().insert(project=project_id, zone=zone, body=request_body).execute()

        # Extract and return the IP address of the new VM
        vm_ip = None
        time.sleep(10)
        instance_name = response.get('targetLink', '').split('/')[-1]

        if instance_name:
            # Fetch details of the newly created instance to get the IP address
            instance = self.compute.instances().get(project=project_id, zone=zone, instance=instance_name).execute()

            # Extract the IP address from the instance details
            network_interfaces = instance.get('networkInterfaces', [])
            if network_interfaces:
                access_configs = network_interfaces[0].get('accessConfigs', [])
                if access_configs:
                    vm_ip = access_configs[0].get('natIP', None)
                    if vm_ip:
                        # Use vm_ip as needed
                        print(f"VM IP Address: {vm_ip}")
                    else:
                        print("Unable to retrieve VM IP address (natIP is None)")
                else:
                    print("No 'accessConfigs' in 'networkInterfaces'")
            else:
                print("No 'networkInterfaces' in instance details")
        else:
            print("Unable to extract instance name from operation response")

        return vm_ip, instance_name

    

    def ssh_key(self, ttl, project_id, ssh_key_path):
        print(ssh_key_path)
        ssh_key_command = [
            'gcloud',
            'compute',
            'os-login',
            'ssh-keys',
            'add',
            f'--ttl={ttl}',
            f'--project={project_id}',
            f'--key-file={ssh_key_path}',
            '--quiet'
        ]

        try:
            subprocess.run(ssh_key_command, check=True)
            print(f"successfully.")
        except subprocess.CalledProcessError as e:
            print(f"Error: {e}")
    
    def scp_to_vm(self, vm_name, username, zone, project_id, ssh_key_path, local_file_path, remote_vm_path):
        scp_command = [
            'gcloud',
            'compute',
            'scp',
            f'--zone={zone}',
            f'--project={project_id}',
            f'--ssh-key-file={ssh_key_path}',
            f'{local_file_path}',
            f'{username}@{vm_name}:{remote_vm_path}',
        ]

        try:
            subprocess.run(scp_command, check=True)
            print(f"File '{local_file_path}' copied to VM '{vm_name}' at '{remote_vm_path}' successfully.")
        except subprocess.CalledProcessError as e:
            print(f"Error: {e}")


    
    def write_to_env_file_remote(self, server_address, username, private_key_path, file_path, key_value_pairs):
        """
        Write key-value pairs to a .env file on a remote server using paramiko.

        Parameters:
        - server_address (str): IP address or hostname of the remote server.
        - username (str): SSH username.
        - private_key_path (str): Path to the private key file for SSH authentication.
        - file_path (str): Path to the .env file on the remote server.
        - key_value_pairs (dict): Dictionary containing key-value pairs.

        Example:
        write_to_env_file_remote('your_server_ip', 'your_username', '/path/to/private/key', '/path/to/.env', {'KEY1': 'value1', 'KEY2': 'value2'})
        """
        try:
            # Create an SSH client
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

            # Connect to the server using private key authentication
            ssh.connect(server_address, username=username, key_filename=private_key_path)

            # Create a temporary local .env file
            local_temp_env_file_path = 'temp_env_file'
            with open(local_temp_env_file_path, 'w') as local_env_file:
                for key, value in key_value_pairs.items():
                    local_env_file.write(f"{key}={value}\n")

            # Upload the local .env file to the remote server
            sftp = ssh.open_sftp()
            sftp.put(local_temp_env_file_path, file_path)
            sftp.close()

            print(f"Successfully wrote to {file_path} on the remote server")

        except Exception as e:
            print(f"Error writing to {file_path} on the remote server: {e}")

        finally:
            # Close the SSH connection
            ssh.close()

    def upload_install_script_and_execute(self, ssh):

        try:
            print("mkdir -p /etc/boostedchat/")
            _, _, _ = ssh.exec_command("mkdir -p /etc/boostedchat/")
            # Upload install.sh
            sftp = ssh.open_sftp()
            print("copying files")
            sftp.put("install.sh", "/root/install.sh")
            sftp.put("/etc/boostedchat/.env", "/etc/boostedchat/.env") # assumes file is already in /etc/boostedchat/.env
            sftp.put("/home/boostedchat/.ssh/boostedchat-site.pem", "/root/.ssh/id_rsa_git") # assumes "/home/boostedchat/.ssh/boostedchat-site.pem" already exists
            sftp.close()
            
            print("chmod +x /root/install.sh")
            _, _, _ = ssh.exec_command("chmod +x /root/install.sh")

            # Execute install.sh
            print("cd /root/ && bash ./install.sh")
            _, stdout, stderr = ssh.exec_command("cd /root/ && bash ./install.sh")

            # Read output and error (if any)
            output = stdout.read().decode("utf-8")
            error = stderr.read().decode("utf-8")

            if output:
                print("Output:", output)
            if error:
                print("Error:", error)

            return True
        except Exception as e:
            print(f"Error copying install.sh to the remote server: {e}")
    
    def copy_file_to_server(self, compute_client, project_id, zone, vm_name, source_path, dest_path):
        try:
            operation = compute_client.instances.copy_files(
                project=project_id,
                zone=zone,
                instance=vm_name,
                source=source_path,
                destination=dest_path
            )
            operation.result()  # Wait for the operation to complete
            print(f"Files copied to {vm_name} successfully")
            return True
        except Exception as error:
            print("Error copying files to the server:", error)
            return
    def run_commands_on_server(self, compute_client, project_id, zone, vm_name, commands):
        try:
            response = compute_client.instances.start_with_encryption_key(
                project=project_id,
                zone=zone,
                instance=vm_name,
                body={"commands": commands},
            ).execute()
            print("Commands executed on the server:", response)
            return True
        except Exception as error:
            print("Error executing commands on the server:", error)
    
    def connect_to_vm_via_gcloud(self, compute_client, project_id, zone, vm_name):
        # Copy files to the server
        print("running mkdir -p /etc/boostedchat/")
        self.run_commands_on_server(compute_client, project_id, zone, vm_name, ["mkdir -p /etc/boostedchat/"])
        print("copying files to server/")
        self.copy_file_to_server(compute_client, project_id, zone, vm_name, "install.sh", "/root/install.sh")
        self.copy_file_to_server(compute_client, project_id, zone, vm_name, "/etc/boostedchat/.env", "/etc/boostedchat/.env")
        print("Running install.sh")
        self.run_commands_on_server(compute_client, project_id, zone, vm_name, ["chmod +x /root/install.sh", "cd /root/ && ./install.sh"])

        # Run commands on the server
        
            
    def connect_to_vm_via_ssh(self, vm_ip, ssh_key_path, vm_username):
        time.sleep(20)
        # try:
        #     self.ssh_key('5d','boostedchatapi', 
        #     ssh_key_path)
        # except Exception as err:
        #     print(f"=========={err}")

        # time.sleep(5)
        
        # Connect to VM via SSH using paramiko
        print("waiting 20 secs")
        try:
            ssh = paramiko.SSHClient()
            ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
            private_key = paramiko.RSAKey(filename=ssh_key_path)
            ssh.connect(vm_ip, username=vm_username, pkey=private_key)
            print("upload_install_script_and_execute")
            self.upload_install_script_and_execute(ssh)
        
            ssh.close()

        except Exception as err:
            print(f"Error connecting to VM: {err}")
        finally:
            if ssh:
                ssh.close()
    
    def post(self, request, *args, **kwargs):
        # Validate input data
        print("starting")
        serializer = CreateVMRequestSerializer(data=request.data)
        if serializer.is_valid():
            # Authentication
            print("authenticating with gcloud")
            project_id, zone = self.authenticate_with_google_cloud()

            # Create VM
            vm_name = request.data.get("company_name")
            vm_ip,_ = self.create_vm(project_id, zone, vm_name)

            # Connect to VM via SSH
            default_ssh_key_path = "/home/boostedchat/.ssh/key.pem"
            ssh_key_path = os.path.join(settings.BASE_DIR, 'key.pem')

            if not os.path.exists(ssh_key_path):
                ssh_key_path = default_ssh_key_path

            print(ssh_key_path)
            vm_username = 'root'

            # self.connect_to_vm_via_gcloud(compute_client, project_id, zone, vm_name)
            print("connect_to_vm_via_ssh")
            self.connect_to_vm_via_ssh(vm_ip, ssh_key_path, vm_username)

            return Response({'status': 'success', 'vm_ip': vm_ip}, status=status.HTTP_200_OK)

        else:
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)
