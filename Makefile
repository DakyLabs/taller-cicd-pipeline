.PHONY: all $(MAKECMDGOALS)

build:
	docker build -t calculator-app .
	@echo ""
	@echo "✓ Imagen lista. Siguiente: make run"

run:
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest python -B app/calc.py

server:
	@echo "→ API disponible en: http://localhost:5001"
	@echo "  Endpoints: /calc/add/3/4  /calc/substract/10/3"
	@echo "  Detener: Ctrl+C"
	@echo ""
	docker run --rm --volume "$(CURDIR):/opt/calc" --name apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -p 5001:5000 -w /opt/calc calculator-app:latest flask run --host=0.0.0.0

interactive:
	docker run -ti --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc  -w /opt/calc calculator-app:latest bash

test-unit:
	mkdir -p results
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pytest --cov --cov-report=xml:results/coverage.xml --cov-report=html:results/coverage --junit-xml=results/unit_result.xml -m unit || true
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/unit_result.xml results/unit_result.html
	@echo ""
	@echo "✓ Resultados en:"
	@echo "  results/unit_result.html    → resultados de los tests"
	@echo "  results/coverage/index.html → cobertura de código"

test-behavior:
	mkdir -p results
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest behave --junit --junit-directory results/  --tags ~@wip test/behavior/
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest bash test/behavior/junit-reports.sh

test-api:
	mkdir -p results
	docker network create calc-test-api || true
	docker run -d --rm --volume "$(CURDIR):/opt/calc" --network calc-test-api --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run --rm --volume "$(CURDIR):/opt/calc" --network calc-test-api --env PYTHONPATH=/opt/calc --env BASE_URL=http://apiserver:5000/ -w /opt/calc calculator-app:latest pytest --junit-xml=results/api_result.xml -m api  || true
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/api_result.xml results/api_result.html
	docker stop apiserver || true
	docker rm --force apiserver || true
	docker network rm calc-test-api
	@echo ""
	@echo "✓ Resultados en: results/api_result.html"

test-e2e:
	mkdir -p results
	docker network create calc-test-e2e || true
	docker stop apiserver || true
	docker rm --force apiserver || true
	docker stop calc-web || true
	docker rm --force calc-web || true
	docker run -d --rm --volume "$(CURDIR):/opt/calc" --network calc-test-e2e --env PYTHONPATH=/opt/calc --name apiserver --env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --volume "$(CURDIR)/web/index.html:/usr/share/nginx/html/index.html" --volume "$(CURDIR)/web/constants.test.js:/usr/share/nginx/html/constants.js" --volume "$(CURDIR)/web/nginx.conf:/etc/nginx/conf.d/default.conf" --network calc-test-e2e --name calc-web -p 80:80 nginx
	docker run --rm --platform linux/amd64 --volume "$(CURDIR)/test/e2e/cypress.json:/cypress.json" --volume "$(CURDIR)/test/e2e/cypress:/cypress" --volume "$(CURDIR)/results:/results"  --network calc-test-e2e cypress/included:4.9.0 --browser chrome || true
	docker rm --force apiserver
	docker rm --force calc-web
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/cypress_result.xml results/cypress_result.html
	docker network rm calc-test-e2e
	@echo ""
	@echo "✓ Resultados en:"
	@echo "  results/cypress_result.html                → reporte de tests"
	@echo "  test/e2e/cypress/screenshots/              → capturas de pantalla"
	@echo "  test/e2e/cypress/videos/calc.spec.js.mp4  → video de la sesión"

test-e2e-wiremock:
	mkdir -p results
	docker network create calc-test-e2e-wiremock || true
	docker stop apiwiremock || true
	docker rm --force apiwiremock || true
	docker stop calc-web || true
	docker rm --force calc-web || true
	docker run -d --rm --name apiwiremock --volume "$(CURDIR)/test/wiremock/stubs:/home/wiremock" --network calc-test-e2e-wiremock -p 8080:8080 -p 8443:8443 calculator-wiremock
	docker run -d --rm --volume "$(CURDIR)/web/index.html:/usr/share/nginx/html/index.html" --volume "$(CURDIR)/web/constants.wiremock.js:/usr/share/nginx/html/constants.js" --volume "$(CURDIR)/web/nginx.conf:/etc/nginx/conf.d/default.conf" --network calc-test-e2e-wiremock --name calc-web -p 80:80 nginx
	docker run --rm --platform linux/amd64 --volume "$(CURDIR)/test/e2e/cypress.json:/cypress.json" --volume "$(CURDIR)/test/e2e/cypress:/cypress" --volume "$(CURDIR)/results:/results" --network calc-test-e2e-wiremock cypress/included:4.9.0 --browser chrome || true
	docker rm --force apiwiremock
	docker rm --force calc-web
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/cypress_result.xml results/cypress_result.html
	docker network rm calc-test-e2e-wiremock
	@echo ""
	@echo "✓ Resultados en:"
	@echo "  results/cypress_result.html                → reporte de tests"
	@echo "  test/e2e/cypress/screenshots/              → capturas de pantalla"
	@echo "  test/e2e/cypress/videos/calc.spec.js.mp4  → video de la sesión"

run-web:
	@echo "→ Frontend disponible en: http://localhost"
	@echo "  Requiere make server corriendo en otra terminal"
	@echo "  Detener: make stop-web"
	@echo ""
	docker run --rm --volume "$(CURDIR)/web/index.html:/usr/share/nginx/html/index.html" --volume "$(CURDIR)/web/constants.local.js:/usr/share/nginx/html/constants.js" --volume "$(CURDIR)/web/nginx.conf:/etc/nginx/conf.d/default.conf" --name calc-web -p 80:80 nginx

stop-web:
	docker stop calc-web

start-sonar-server:
	docker network create calc-sonar || true
	docker run -d --rm --stop-timeout 60 --network calc-sonar --name sonarqube-server -p 9000:9000 --volume "$(CURDIR)/sonar/data:/opt/sonarqube/data" --volume "$(CURDIR)/sonar/logs:/opt/sonarqube/logs" sonarqube:community
	@echo ""
	@echo "→ SonarQube disponible en: http://localhost:9000"
	@echo "  Usuario: admin  |  Contraseña: admin"
	@echo "  Espera 30-40 segundos antes de abrir el navegador"
	@echo "  Siguiente: make pylint && make test-unit && make start-sonar-scanner"

stop-sonar-server:
	docker stop sonarqube-server
	docker network rm calc-sonar || true

start-sonar-scanner:
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════╗"
	@echo "║              SONARQUBE — OBTENER TOKEN                      ║"
	@echo "╠══════════════════════════════════════════════════════════════╣"
	@echo "║  1. Abre http://localhost:9000                               ║"
	@echo "║  2. Login: usuario=admin  contraseña=admin                  ║"
	@echo "║  3. Clic en tu avatar (arriba a la derecha)                 ║"
	@echo "║  4. My Account → pestaña Security                           ║"
	@echo "║  5. Generate Token → escribe un nombre → Generate           ║"
	@echo "║  6. Copia el token (sqa_...)                                ║"
	@echo "╚══════════════════════════════════════════════════════════════╝"
	@echo ""
	@read -p "Pega el token aquí y presiona Enter: " token; \
	docker run --rm --network calc-sonar -v "$(CURDIR):/usr/src" \
		-e SONAR_TOKEN=$$token \
		sonarsource/sonar-scanner-cli
	@echo ""
	@echo "✓ Análisis enviado a SonarQube"
	@echo "  Ver resultados en: http://localhost:9000"

pylint:
	mkdir -p results
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest pylint app/ | tee results/pylint_result.txt
	@echo ""
	@echo "✓ Resultados en: results/pylint_result.txt"

build-wiremock:
	docker build -t calculator-wiremock -f test/wiremock/Dockerfile test/wiremock/
	@echo ""
	@echo "✓ Imagen WireMock lista. Siguiente: make test-e2e-wiremock"

start-wiremock:
	docker run -d --rm --name calculator-wiremock --volume "$(CURDIR)/test/wiremock/stubs:/home/wiremock" -p 8080:8080 -p 8443:8443 calculator-wiremock
	@echo ""
	@echo "→ WireMock disponible en: http://localhost:8080"
	@echo "  Prueba: curl http://localhost:8080/calc/add/1/2"
	@echo "  Detener: make stop-wiremock"

stop-wiremock:
	docker stop calculator-wiremock || true

ZAP_API_KEY := my_zap_api_key
ZAP_API_URL := http://zap-node:8080/
ZAP_TARGET_URL := http://calc-web/
zap-scan:
	mkdir -p results
	docker network create calc-test-zap || true
	docker run -d --rm --network calc-test-zap --volume "$(CURDIR):/opt/calc" --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --network calc-test-zap --volume "$(CURDIR)/web/index.html:/usr/share/nginx/html/index.html" --volume "$(CURDIR)/web/constants.test.js:/usr/share/nginx/html/constants.js" --volume "$(CURDIR)/web/nginx.conf:/etc/nginx/conf.d/default.conf" --name calc-web -p 80:80 nginx
	docker run -d --rm --network calc-test-zap --name zap-node -u zap -p 8080:8080 -i owasp/zap2docker-stable zap.sh -daemon -host 0.0.0.0 -port 8080 -config api.addrs.addr.name=.* -config api.addrs.addr.regex=true -config api.key=$(ZAP_API_KEY)
	sleep 10
	docker run --rm --volume "$(CURDIR):/opt/calc" --network calc-test-zap --env PYTHONPATH=/opt/calc --env ZAP_API_KEY=$(ZAP_API_KEY) --env ZAP_API_URL=$(ZAP_API_URL) --env TARGET_URL=$(ZAP_TARGET_URL) -w /opt/calc calculator-app:latest pytest --junit-xml=results/sec_result.xml -m security  || true
	docker run --rm --volume "$(CURDIR):/opt/calc" --env PYTHONPATH=/opt/calc -w /opt/calc calculator-app:latest junit2html results/sec_result.xml results/sec_result.html
	docker stop apiserver || true
	docker stop calc-web || true
	docker stop zap-node || true
	docker network rm calc-test-zap || true
	@echo ""
	@echo "✓ Resultados en: results/sec_result.html"

build-jmeter:
	docker build -t calculator-jmeter -f test/jmeter/Dockerfile test/jmeter
	@echo ""
	@echo "✓ Imagen JMeter lista. Siguiente: make jmeter-load"

start-jmeter-record:
	docker network create calc-test-jmeter || true
	docker run -d --rm --network calc-test-jmeter --volume "$(CURDIR):/opt/calc" --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	docker run -d --rm --network calc-test-jmeter --volume "$(CURDIR)/web/index.html:/usr/share/nginx/html/index.html" --volume "$(CURDIR)/web/constants.test.js:/usr/share/nginx/html/constants.js" --volume "$(CURDIR)/web/nginx.conf:/etc/nginx/conf.d/default.conf" --name calc-web -p 80:80 nginx
	@echo ""
	@echo "→ API en: http://localhost:5001"
	@echo "  Frontend en: http://localhost"
	@echo "  Detener: make stop-jmeter-record"

stop-jmeter-record:
	docker stop apiserver || true
	docker stop calc-web || true
	docker network rm calc-test-jmeter || true


JMETER_RESULTS_FILE := results/jmeter_results.csv
JMETER_REPORT_FOLDER := results/jmeter/
jmeter-load:
	mkdir -p results
	rm -f $(JMETER_RESULTS_FILE)
	rm -rf $(JMETER_REPORT_FOLDER)
	docker network create calc-test-jmeter || true
	docker run -d --rm --network calc-test-jmeter --volume "$(CURDIR):/opt/calc" --name apiserver --network-alias apiserver --env PYTHONPATH=/opt/calc --env FLASK_APP=app/api.py -w /opt/calc calculator-app:latest flask run --host=0.0.0.0
	sleep 5
	docker run --rm --network calc-test-jmeter --volume "$(CURDIR):/opt/jmeter" -w /opt/jmeter calculator-jmeter jmeter -n -t test/jmeter/jmeter-plan.jmx -l results/jmeter_results.csv -e -o results/jmeter/
	docker stop apiserver || true
	docker network rm calc-test-jmeter || true
	@echo ""
	@echo "✓ Prueba de carga completada."
	@echo "  Iniciando servidor para ver el reporte..."
	@lsof -ti :8888 | xargs kill -9 2>/dev/null || true
	@cd results/jmeter && python3 -m http.server 8888 &
	@sleep 1
	@echo ""
	@echo "╔══════════════════════════════════════════════════════╗"
	@echo "║           REPORTE JMETER DISPONIBLE                 ║"
	@echo "╠══════════════════════════════════════════════════════╣"
	@echo "║  Dashboard:       http://localhost:8888              ║"
	@echo "║  Tiempos:         http://localhost:8888/content/pages/ResponseTimes.html  ║"
	@echo "║  Throughput:      http://localhost:8888/content/pages/Throughput.html     ║"
	@echo "║  Over Time:       http://localhost:8888/content/pages/OverTime.html       ║"
	@echo "╠══════════════════════════════════════════════════════╣"
	@echo "║  Para detener:  make stop-jmeter-report             ║"
	@echo "╚══════════════════════════════════════════════════════╝"

stop-jmeter-report:
	@lsof -ti :8888 | xargs kill -9 2>/dev/null || true
	@echo "✓ Servidor de reporte JMeter detenido"
