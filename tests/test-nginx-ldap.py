#!/usr/bin/env python3

import argparse
import socket
import sys
import time
import unittest

START_TIMEOUT = 120  # seconds to wait for the container to be usable
HTTP_PORT = 80
HOST_PORT = 18080  # the port of the host the port of nginx is mapped to


def wait_for_container(container, timeout=START_TIMEOUT):
    print("Waiting for the container to be usable...")
    deadline = time.time() + timeout
    while True:
        container.reload()
        state = container.attrs.get("State", {})
        status = state.get("Status")
        if status in ("exited", "dead"):
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(
                f"The container stopped before it was usable (status={status}).\n{logs}"
            )
        if status == "running":
            try:
                if container.exec_run(["true"]).exit_code == 0:
                    print("The container is usable.")
                    return
            except Exception:
                pass
        if time.time() > deadline:
            logs = container.logs().decode("utf-8", errors="replace")
            raise RuntimeError(f"The container was not usable within {timeout}s.\n{logs}")
        time.sleep(2)


def run_tests(image_name):
    import docker

    class TestNginxLdap(unittest.TestCase):
        @classmethod
        def setUpClass(cls):
            cls.client = docker.from_env()
            cls.container = cls.client.containers.run(
                image_name,
                detach=True,
                ports={f"{HTTP_PORT}/tcp": f"{HOST_PORT}"},
            )
            wait_for_container(cls.container)

        @classmethod
        def tearDownClass(cls):
            cls.container.stop()
            cls.container.remove()

        def test_the_configuration_is_good(self):
            print("Running the configuration test...")
            result = self.container.exec_run(["nginx", "-t"])
            output = result.output.decode("utf-8", errors="replace")
            self.assertEqual(
                result.exit_code, 0, f"The configuration of nginx is not good: {output}"
            )
            print("Configuration test passed.")

        def test_the_module_for_the_directory_is_there(self):
            print("Running the module test...")
            result = self.container.exec_run(["nginx", "-V"])
            output = result.output.decode("utf-8", errors="replace")
            self.assertIn("nginx-auth-ldap", output, "The module for ldap is not in nginx")
            print("Module test passed.")

        def test_the_port_is_open(self):
            print("Running the port test...")
            deadline = time.time() + 60
            last_error = None
            while True:
                try:
                    with socket.create_connection(("127.0.0.1", HOST_PORT), timeout=5):
                        print("Port test passed.")
                        return
                except OSError as error:
                    last_error = error
                if time.time() > deadline:
                    self.fail(f"The port of nginx is not open: {last_error}")
                time.sleep(2)

    print(f"Starting the container from the image '{image_name}'...")
    suite = unittest.TestLoader().loadTestsFromTestCase(TestNginxLdap)
    result = unittest.TextTestRunner(verbosity=2).run(suite)
    if not result.wasSuccessful():
        sys.exit(1)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run the tests for the nginx ldap image.")
    parser.add_argument(
        "--image",
        type=str,
        default="satishweb/nginx-ldap:ci",
        help="The image that is tested",
    )
    args = parser.parse_args()

    run_tests(args.image)
