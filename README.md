# Taller CI/CD — Pipeline completo con Python y Docker

> Basado en [srayuso/unir-test](https://github.com/srayuso/unir-test) (UNIR - EIEC DevOps).  
> Actualizado y extendido en 2026 para compatibilidad con Apple Silicon (ARM64) y Linux x86.

Pipeline completo de CI/CD usando una calculadora web como proyecto de ejemplo. Cubre desde pruebas unitarias hasta seguridad y carga, todo orquestado con Docker y Make.

---

## Requisitos

- Docker Desktop instalado
- Make
- Git

No necesitas instalar Python, Node.js ni ninguna otra herramienta. Todo corre dentro de contenedores Docker.

---

## Inicio rápido

```bash
# 1. Clonar el repo
git clone https://github.com/DakyLabs/taller-cicd-pipeline.git
cd taller-cicd-pipeline

# 2. Construir la imagen base
make build

# 3. Verificar que funciona
make run
# Output esperado: 4

# 4. Levantar el servidor API
make server
# API disponible en: http://localhost:5001

# 5. Levantar el frontend
make run-web
# Frontend disponible en: http://localhost
```

---

## Arquitectura

```
app/
├── calc.py       → lógica de negocio (Calculator)
├── api.py        → API REST con Flask
└── util.py       → funciones de utilidad

web/
├── index.html    → frontend con Vue.js
└── nginx.conf    → configuración del servidor web

test/
├── unit/         → pruebas unitarias (pytest)
├── behavior/     → pruebas BDD (behave + Gherkin)
├── rest/         → pruebas de API REST (pytest)
├── e2e/          → pruebas de navegador (Cypress)
├── sec/          → pruebas de seguridad (OWASP ZAP)
├── jmeter/       → pruebas de carga (JMeter)
└── wiremock/     → mock del backend (WireMock)
```

---

## Comandos

### Aplicación

| Comando | Qué hace | Dónde se ve |
|---------|----------|-------------|
| `make build` | Construye la imagen Docker | — |
| `make run` | Ejecuta calc.py (imprime 4) | Terminal |
| `make server` | Levanta la API Flask | http://localhost:5001 |
| `make run-web` | Levanta el frontend nginx | http://localhost |
| `make interactive` | Shell bash dentro del contenedor | Terminal |

### Pruebas

| Comando | Herramienta | Qué prueba | Resultados |
|---------|-------------|------------|------------|
| `make test-unit` | pytest | Lógica de la calculadora | `results/unit_result.html` + `results/coverage/` |
| `make test-behavior` | behave | Escenarios BDD en Gherkin | `results/` |
| `make test-api` | pytest | Endpoints HTTP reales | `results/api_result.html` |
| `make test-e2e` | Cypress + Chrome | App completa en el navegador | `results/cypress_result.html` + screenshots + video |
| `make test-e2e-wiremock` | Cypress + WireMock | Frontend con backend simulado | `results/cypress_result.html` |
| `make pylint` | pylint | Calidad y estilo del código | `results/pylint_result.txt` |
| `make zap-scan` | OWASP ZAP | Vulnerabilidades de seguridad | `results/sec_result.html` |
| `make jmeter-load` | JMeter | Carga con 100 usuarios simultáneos | http://localhost:8888 (se abre automáticamente) |

### WireMock

```bash
make build-wiremock    # construye la imagen
make start-wiremock    # levanta el mock en localhost:8080
make stop-wiremock     # detiene el mock
```

### SonarQube

```bash
make start-sonar-server    # levanta SonarQube en localhost:9000
make pylint                # genera reporte de análisis estático
make test-unit             # genera reporte de cobertura
make start-sonar-scanner   # envía todo a SonarQube (pide token)
make stop-sonar-server     # detiene SonarQube
```

---

## Tipos de pruebas explicados

### Unitarias
Prueban funciones individuales en aislamiento. No necesitan red ni servidor.
```bash
make test-unit
open results/unit_result.html
open results/coverage/index.html
```

### BDD (Behavior Driven Development)
Escenarios escritos en lenguaje humano (Given/When/Then) que el equipo de negocio puede leer y validar.
```bash
make test-behavior
```

### API REST
Hacen peticiones HTTP reales al servidor Flask desde un segundo contenedor en red Docker privada.
```bash
make test-api
open results/api_result.html
```

### E2E con Cypress
Abren Chrome automáticamente, interactúan con la calculadora como un usuario real y toman screenshots y video.
```bash
make test-e2e
open test/e2e/cypress/screenshots/
open test/e2e/cypress/videos/
```

### Seguridad con OWASP ZAP
Escaneo automático de vulnerabilidades (XSS, inyección, cabeceras inseguras, etc).
```bash
make zap-scan
open results/sec_result.html
```

### Carga con JMeter
Simula 100 usuarios simultáneos haciendo 10 peticiones cada uno (2000 peticiones en total).
```bash
make jmeter-load
# El dashboard se abre automáticamente en http://localhost:8888
make stop-jmeter-report  # cuando termines
```

---

## Notas de compatibilidad

| Plataforma | Estado |
|------------|--------|
| Mac Apple Silicon (M1/M2/M3) | Funciona |
| Mac Intel | Funciona |
| Linux x86_64 | Funciona |
| Windows | Requiere WSL2 con Docker |

---

## Cambios respecto al original

- Fix rutas con espacios en el Makefile (`pwd` → `$(CURDIR)` con comillas)
- Fix puerto 5000 → 5001 para evitar conflicto con AirPlay Receiver en macOS
- Fix montajes anidados en contenedores nginx (virtiofs en Mac)
- Fix `openjdk:8-jre` eliminado de Docker Hub → `eclipse-temurin:11-jre`
- Fix `sonarqube:8.3.1-community` sin ARM64 → `sonarqube:community`
- Fix Cypress sin ARM64 → `--platform linux/amd64`
- Mensajes informativos con URLs en cada comando
- Token de SonarQube interactivo con instrucciones paso a paso
- JMeter configurado con 100 usuarios y servidor automático de reporte
- Manual completo en `MANUAL.md`

---

## Crédito

Proyecto original: [srayuso/unir-test](https://github.com/srayuso/unir-test) — UNIR, asignatura EIEC DevOps.
