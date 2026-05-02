import html
import os
import unittest
import time

import pytest
from zapv2 import ZAPv2

TARGET_URL = os.environ.get("TARGET_URL")
ZAP_API_URL = os.environ.get("ZAP_API_URL")
ZAP_API_KEY = os.environ.get("ZAP_API_KEY")
DEFAULT_WAIT = 2  # in secs
DEFAULT_TIMEOUT = 120  # in secs


@pytest.mark.security
class TestApi(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(TARGET_URL, "URL no configurada")
        self.assertTrue(len(TARGET_URL) > 8, "URL no configurada")
        self.assertIsNotNone(ZAP_API_URL, "ZAP API URL no configurada")
        self.assertTrue(len(ZAP_API_URL) > 8, "ZAP API URL no configurada")
        self.assertIsNotNone(ZAP_API_KEY, "ZAP API key no configurada")
        self.assertTrue(len(ZAP_API_KEY) > 8, "ZAP API key no configurada")

        print(f"Test configurado con {TARGET_URL}, {ZAP_API_URL}")

    def test_security_scan(self):
        zap = ZAPv2(apikey=ZAP_API_KEY, proxies={'http': ZAP_API_URL, 'https': ZAP_API_URL})

        print("Empezando exploración")
        explore_id = zap.ajaxSpider.scan(TARGET_URL)
        print(f"ID exploración: {explore_id}")

        timeout = time.time() + DEFAULT_TIMEOUT
        while zap.ajaxSpider.status == 'running':
            if time.time() > timeout:
                break

            time.sleep(DEFAULT_WAIT)

        assert zap.ajaxSpider.status == 'stopped', 'La exploración con ZAP excedió el timeout'
        explore_results = zap.ajaxSpider.results(start=0, count=10)
        print("Resultado de la exploración: {}".format(explore_results))

        print("Empezando escaneo")
        scan_id = zap.ascan.scan(TARGET_URL)
        timeout = time.time() + DEFAULT_TIMEOUT
        while int(zap.ascan.status(scan_id)) < 100:
            if time.time() > timeout:
                break

            time.sleep(DEFAULT_WAIT)

        assert int(zap.ascan.status(scan_id)) == 100, 'El escaneo con ZAP excedió el timeout'

        alerts = zap.core.alerts(baseurl=TARGET_URL)
        with open('results/sec_report.html', 'w') as f:
            f.write(build_html(zap.core.hosts, alerts))

        assert len(alerts) == 0, "Se encontraron vulnerabilidades en el escaneo con ZAP"


TOP_HTML = """
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8" />
    <title>Security results</title>
    <link
      rel="stylesheet"
      href="https://stackpath.bootstrapcdn.com/bootstrap/4.3.1/css/bootstrap.min.css"
      integrity="sha384-ggOyR0iXCbMQv3Xipma34MD+dH/1fQ784/j6cY/iJTQUOhcWr7x9JvoRxT2MZw1T"
      crossorigin="anonymous"
    />
    <style>
      html {
        position: relative;
      }

      body {
        background: #ffffff;
        margin: 0;
      }

      main {
        padding: 20px;
      }
      .main-column {
        margin-bottom: 100px;
      }
    </style>
  </head>
  <body class="d-flex flex-column h-100">
    <main class="flex-shrink-0">
"""

BOTTOM_HTML = """
    </main>
  </body>
</html>

"""


def build_html(hosts, alerts):
    body = TOP_HTML
    body = (
        body
        + """
        <h1>Hosts escaneados</h1>
        <ul>
    """
    )
    for host in hosts:
        host_html = f"""
            <li>{host}</li>
            """
        body = body + host_html

    body = (
        body
        + """
        </ul>
        <h1>Vulnerabilidades</h1>
    """
    )
    for alert in alerts:
        evidence = html.escape(alert.get("evidence"))
        alert_html = f"""
        <ul>
            <li>
                <h3>{alert.get("name")}</h3>
                <ul>
                    <li><b>Description</b>: {alert.get("description")}</li>
                    <li><b>Evidence</b>: {evidence}</li>
                    <li><b>Confidence</b>: {alert.get("confidence")}</li>
                    <li><b>Solution</b>: {alert.get("solution")}</li>
                </ul>
            </li>
        </ul>
        """
        body = body + alert_html

    body = body + BOTTOM_HTML
    return body
