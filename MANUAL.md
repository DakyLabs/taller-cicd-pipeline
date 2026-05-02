# Manual del Laboratorio: Pipeline de CI/CD con Python + Docker

> Proyecto: Calculadora Web con suite completa de testing  
> Audiencia: Taller de 2 horas sobre CI/CD  
> Nivel: Intermedio

---

## Índice

1. [Arquitectura general del proyecto](#1-arquitectura-general)
2. [Requisitos previos](#2-requisitos-previos)
3. [Estructura de archivos](#3-estructura-de-archivos)
4. [La aplicación: Calculadora Flask](#4-la-aplicación-calculadora-flask)
5. [Docker: cómo se empaqueta todo](#5-docker)
6. [El Makefile: orquestador de comandos](#6-el-makefile)
7. [Tipos de pruebas y cómo ejecutarlas](#7-tipos-de-pruebas)
8. [Problemas comunes y soluciones](#8-problemas-comunes)
9. [Plan del taller CI/CD (2 horas)](#9-plan-del-taller-cicd)
10. [GitHub Actions: pipeline completo](#10-github-actions)
11. [Despliegue en la nube](#11-despliegue-en-la-nube)
12. [Estado de las herramientas (2025)](#12-estado-de-las-herramientas)

---

## 1. Arquitectura general

```
┌─────────────────────────────────────────────────┐
│                   APLICACIÓN                    │
│                                                 │
│  app/calc.py   ←  lógica de negocio (Python)    │
│  app/util.py   ←  utilidades                    │
│  app/api.py    ←  servidor HTTP (Flask)          │
│  web/          ←  frontend (HTML + Vue.js)      │
└─────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────┐
│               SUITE DE TESTING                  │
│                                                 │
│  test/unit/        → pytest (lógica)            │
│  test/behavior/    → behave/Gherkin (BDD)       │
│  test/rest/        → pytest (API HTTP)          │
│  test/e2e/         → Cypress (navegador)        │
│  test/sec/         → OWASP ZAP (seguridad)      │
│  test/jmeter/      → JMeter (carga/rendimiento) │
│  test/wiremock/    → WireMock (stubs/mocks)     │
└─────────────────────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────┐
│               INFRAESTRUCTURA                   │
│                                                 │
│  Dockerfile        → imagen base Python          │
│  Makefile          → comandos de automatización  │
│  sonar-project.properties → análisis de calidad │
└─────────────────────────────────────────────────┘
```

---

## 2. Requisitos previos

| Herramienta | Versión mínima | Para qué se usa |
|-------------|---------------|-----------------|
| Docker Desktop | 20.x+ | Ejecutar todo |
| Make | cualquiera | Orquestar comandos |
| Git | 2.x+ | Control de versiones |
| Cuenta GitHub | — | CI/CD con Actions |

**No necesitas Python instalado localmente.** Todo corre dentro de contenedores Docker.

### macOS: problema con el puerto 5000

En macOS Monterey y superiores, el sistema ocupa el puerto 5000 para AirPlay Receiver.  
Para liberar el puerto: **Ajustes del Sistema → General → AirDrop y Handoff → Receptor AirPlay → Desactivar**.

---

## 3. Estructura de archivos

```
unir-test-master/
│
├── Dockerfile                  # Imagen Docker de la app Python
├── Makefile                    # Todos los comandos del proyecto
├── requires                    # Dependencias Python (pip)
├── pytest.ini                  # Configuración de pytest
├── sonar-project.properties    # Config de análisis SonarQube
│
├── app/                        # Código fuente de la aplicación
│   ├── calc.py                 # Clase Calculator (lógica pura)
│   ├── api.py                  # API REST con Flask
│   └── util.py                 # Funciones de utilidad
│
├── web/                        # Frontend estático
│   ├── index.html              # UI con Vue.js
│   ├── nginx.conf              # Configuración de nginx
│   ├── constants.local.js      # URL del API en local
│   ├── constants.test.js       # URL del API en tests
│   └── constants.wiremock.js   # URL cuando se usa WireMock
│
├── test/
│   ├── unit/                   # Pruebas unitarias (pytest)
│   │   ├── calc_test.py
│   │   └── util_test.py
│   │
│   ├── behavior/               # Pruebas BDD (behave + Gherkin)
│   │   ├── features/
│   │   │   ├── calculator.feature
│   │   │   └── calculator-scientific.feature
│   │   └── steps/
│   │       └── calculator.py
│   │
│   ├── rest/                   # Pruebas de API (pytest)
│   │   └── api_test.py
│   │
│   ├── e2e/                    # Pruebas end-to-end (Cypress)
│   │   ├── cypress.json
│   │   └── cypress/
│   │       ├── fixtures/       # datos de prueba
│   │       └── integration/    # specs de Cypress
│   │           └── calc.spec.js
│   │
│   ├── sec/                    # Pruebas de seguridad (OWASP ZAP)
│   │   └── owasp_zap_test.py
│   │
│   ├── jmeter/                 # Pruebas de carga
│   │   ├── Dockerfile
│   │   └── jmeter-plan.jmx
│   │
│   └── wiremock/               # Mock del servidor API
│       ├── Dockerfile
│       └── stubs/
│           ├── __files/        # respuestas estáticas
│           └── mappings/       # configuración de rutas mock
│
└── results/                    # Artefactos generados (en .gitignore)
    ├── unit_result.xml/html
    ├── api_result.xml/html
    ├── coverage.xml
    └── ...
```

---

## 4. La aplicación: Calculadora Flask

### 4.1 Lógica de negocio (`app/calc.py`)

La clase `Calculator` implementa operaciones matemáticas básicas. Lo interesante para CI/CD es que **valida permisos** llamando a `util.validate_permissions()`, lo que permite demostrar mocking en pruebas.

```python
class Calculator:
    def add(self, x, y):     ...
    def substract(self, x, y): ...
    def multiply(self, x, y):  # ← requiere permiso de "user1"
    def divide(self, x, y):  ...
    def power(self, x, y):   ...
```

### 4.2 API REST (`app/api.py`)

Servidor Flask que expone endpoints HTTP:

| Endpoint | Método | Ejemplo |
|----------|--------|---------|
| `/` | GET | `Hello from The Calculator!` |
| `/calc/add/3/4` | GET | `7` |
| `/calc/substract/10/3` | GET | `7` |

**Variable de entorno**: `FLASK_APP=app/api.py`  
**Variable importante**: `PYTHONPATH=/opt/calc` (para que Python encuentre el módulo `app`)

### 4.3 Frontend (`web/index.html`)

Página estática con Vue.js que llama a la API. La URL base viene del archivo `constants.js` que se inyecta según el entorno:

- `constants.local.js` → `http://localhost:5000` (desarrollo)
- `constants.test.js` → `http://apiserver:5000` (dentro de Docker network)
- `constants.wiremock.js` → `http://apiwiremock:8080` (con WireMock)

---

## 5. Docker

### 5.1 Imagen principal (`Dockerfile`)

```dockerfile
FROM python:3.6-slim          # imagen base mínima de Python

RUN mkdir -p /opt/calc        # crea el directorio de trabajo

WORKDIR /opt/calc             # directorio por defecto

COPY requires ./              # copia lista de dependencias
RUN pip install -r requires   # instala paquetes
```

**Punto clave**: el código fuente NO se copia en la imagen. Se monta en tiempo de ejecución con `-v`. Esto hace los contenedores más rápidos de re-construir durante desarrollo.

### 5.2 Dependencias (`requires`)

```
behave==1.2.6              # BDD testing
flask==1.1.2               # servidor web
pytest==5.4.3              # framework de pruebas
pytest-cov==2.10.0         # cobertura de código
pylint==2.5.3              # análisis estático
junit2html                 # convierte XML a HTML legible
python-owasp-zap-v2.4     # cliente para OWASP ZAP
```

### 5.3 Redes Docker (Networks)

Los tests que involucran múltiples contenedores crean una red Docker temporal:

```
┌──────────────────────────────────────┐
│   Red: calc-test-api                 │
│                                      │
│  ┌──────────┐    ┌────────────────┐  │
│  │ apiserver│←──│ pytest (tests) │  │
│  │ :5000    │    └────────────────┘  │
│  └──────────┘                        │
└──────────────────────────────────────┘
```

Dentro de la red, los contenedores se comunican por nombre (`http://apiserver:5000`).

---

## 6. El Makefile

El Makefile es el **orquestador central**. Cada target ejecuta comandos Docker específicos.

### Comandos disponibles

| Comando | Qué hace |
|---------|----------|
| `make build` | Construye la imagen Docker `calculator-app` |
| `make run` | Ejecuta `calc.py` directamente (imprime 4) |
| `make server` | Levanta el servidor Flask en `localhost:5000` |
| `make interactive` | Abre una shell bash dentro del contenedor |
| `make test-unit` | Corre pruebas unitarias con pytest |
| `make test-behavior` | Corre pruebas BDD con behave |
| `make test-api` | Corre pruebas de API REST |
| `make test-e2e` | Corre pruebas E2E con Cypress (Chrome) |
| `make test-e2e-wiremock` | E2E con backend simulado (WireMock) |
| `make pylint` | Análisis estático del código |
| `make run-web` | Levanta el frontend en `localhost:80` |
| `make build-wiremock` | Construye imagen WireMock |
| `make zap-scan` | Escaneo de seguridad con OWASP ZAP |
| `make build-jmeter` | Construye imagen JMeter |
| `make jmeter-load` | Prueba de carga con JMeter |
| `make start-sonar-server` | Levanta SonarQube en `localhost:9000` |
| `make start-sonar-scanner` | Ejecuta el análisis de calidad |

### Flujo de trabajo básico (inicio rápido)

```bash
# 1. Construir la imagen (solo una vez)
make build

# 2. Verificar que la app funciona
make run
# Output esperado: 4

# 3. Levantar el servidor API
make server
# Abre otra terminal y prueba: curl http://localhost:5000/calc/add/3/4

# 4. Correr pruebas unitarias
make test-unit
# Resultados en: results/unit_result.html

# 5. Correr pruebas de comportamiento (BDD)
make test-behavior
```

---

## 7. Tipos de pruebas

### 7.1 Pruebas Unitarias (`test/unit/`)

**Herramienta**: pytest  
**Qué prueban**: la clase `Calculator` en aislamiento  
**Marca pytest**: `@pytest.mark.unit`

```python
def test_add_method_returns_correct_result(self):
    self.assertEqual(4, self.calc.add(2, 2))

@patch('app.util.validate_permissions', side_effect=mocked_validation)
def test_multiply_method_returns_correct_result(self, _validate_permissions):
    # mock de validate_permissions para pruebas aisladas
    self.assertEqual(4, self.calc.multiply(2, 2))
```

**Concepto clave**: `@patch` reemplaza `validate_permissions` con una función que siempre retorna `True`, aislando la prueba del sistema de permisos.

**Ejecutar**:
```bash
make test-unit
# Resultados: results/unit_result.html + results/coverage/index.html
```

### 7.2 Pruebas de Comportamiento BDD (`test/behavior/`)

**Herramienta**: behave (Gherkin)  
**Qué prueban**: comportamiento desde la perspectiva del negocio  
**Lenguaje**: Given/When/Then (inglés o español)

**Feature file** (`calculator.feature`):
```gherkin
Feature: Calculator basic usage

  Scenario: Use the add operation
    Given I open the calculator
    When I type 2 + 2
    Then the result is 4

  Scenario Outline: Use the add operation multiple times
    Given I open the calculator
    When I type <op_1> + <op_2>
    Then the result is <res>

    Examples: Add numbers
      | op_1 | op_2 | res |
      | 2    | 2    | 4   |
      | 1    | 0    | 1   |
      | 1    | -1   | 0   |
```

**Ejecutar**:
```bash
make test-behavior
```

### 7.3 Pruebas de API REST (`test/rest/api_test.py`)

**Herramienta**: pytest  
**Qué prueban**: endpoints HTTP del servidor Flask  
**Marca pytest**: `@pytest.mark.api`  
**Configuración**: variable de entorno `BASE_URL=http://apiserver:5000/`

**Arquitectura del test**:
```
Terminal 1: servidor Flask corriendo
Terminal 2: pytest haciendo peticiones HTTP reales
```

En el Makefile, `make test-api` automatiza esto:
1. Crea una red Docker `calc-test-api`
2. Lanza el servidor Flask en la red
3. Lanza pytest en la misma red
4. Para y limpia todo al terminar

**Ejecutar**:
```bash
make test-api
# Resultados: results/api_result.html
```

### 7.4 Pruebas End-to-End con Cypress (`test/e2e/`)

**Herramienta**: Cypress 4.9.0 (`cypress/included:4.9.0`)  
**Qué prueban**: la aplicación completa desde el navegador (Chrome)  
**Características**: toma screenshots y videos automáticamente

**Spec file** (`calc.spec.js`):
```javascript
it('can click add', () => {
    cy.get('#in-op1').clear().type('2')      // escribe en campo 1
    cy.get('#in-op2').clear().type('3')      // escribe en campo 2
    cy.get('#button-add').click()            // hace clic en "+"
    cy.get('#result-area').should('have.text', "Result: 5")  // verifica
    cy.screenshot()                          // captura pantalla
})
```

**Arquitectura para el test**:
```
┌─────────────────────────────────────────┐
│  Red: calc-test-e2e                     │
│                                         │
│  apiserver:5000  ←  calc-web:80  ←  Cypress  │
│  (Flask)            (nginx)        (Chrome)  │
└─────────────────────────────────────────┘
```

**Ejecutar**:
```bash
make test-e2e
# Screenshots: test/e2e/cypress/screenshots/
# Resultados: results/cypress_result.html
```

### 7.5 Pruebas con WireMock (`test/wiremock/`)

WireMock es un servidor que simula el backend. Permite probar el frontend sin depender de la API real.

**Stubs configurados** (en `test/wiremock/stubs/mappings/`):
```json
// add12.json: simula GET /calc/add/1/2 → responde "3"
// add23.json: simula GET /calc/add/2/3 → responde "5"
// mult23.json: simula GET /calc/multiply/2/3 → responde "6"
```

**Para qué sirve**: probar el frontend de forma aislada, sin necesitar el backend Python funcionando.

**Ejecutar**:
```bash
make build-wiremock
make test-e2e-wiremock
```

### 7.6 Análisis de Calidad con SonarQube

SonarQube analiza la calidad del código: bugs, vulnerabilidades, cobertura, duplicaciones.

```bash
make start-sonar-server    # inicia SonarQube en localhost:9000
make pylint                # genera reporte de pylint (input para Sonar)
make test-unit             # genera reporte de cobertura (input para Sonar)
make start-sonar-scanner   # ejecuta el análisis y lo envía a SonarQube
```

Abre `http://localhost:9000` para ver los resultados.

### 7.7 Pruebas de Seguridad con OWASP ZAP

OWASP ZAP hace un escaneo de vulnerabilidades (XSS, SQL injection, etc.) contra la app web.

```bash
make zap-scan
# Resultados: results/sec_result.html
```

### 7.8 Pruebas de Carga con JMeter

JMeter simula múltiples usuarios concurrentes haciendo peticiones a la API.

```bash
make build-jmeter
make jmeter-load
# Reporte HTML: results/jmeter/index.html
```

---

## 8. Problemas comunes y soluciones

### Error: `Unable to find image 'de:latest'`

**Causa**: el path del proyecto tiene espacios y el Makefile usa `pwd` sin comillas.  
**Solución**: ya está corregido en este repositorio usando `$(CURDIR)` con comillas.  
**Lección**: siempre mover proyectos a paths sin espacios (`~/Projects/lab-cicd`).

### Error: `address already in use` en puerto 5000

**Causa**: macOS Monterey+ usa el puerto 5000 para AirPlay Receiver.  
**Solución**: Ajustes → General → AirDrop y Handoff → Receptor AirPlay → desactivar.

### Error al hacer `make build` (imagen no disponible ARM64)

**Causa**: `python:3.6-slim` no tiene imagen ARM64 nativa (M1/M2/M3).  
**Solución**: Docker Desktop con Rosetta activa suele manejarlo con emulación. Si falla:
```bash
# Forzar plataforma AMD64 con emulación
docker build --platform linux/amd64 -t calculator-app .
```
Para producción, actualizar a `python:3.11-slim`.

### `make test-e2e` falla en Mac con Apple Silicon

**Causa**: `cypress/included:4.9.0` no tiene imagen ARM64.  
**Solución**: actualizar a una versión moderna de Cypress que sí soporta ARM64:
```bash
# En el Makefile cambiar:
cypress/included:4.9.0
# Por:
cypress/included:13.6.0
```

### `make build-wiremock` falla con `openjdk:8-jre`

**Causa**: `openjdk:8-jre` fue deprecado y removido de Docker Hub.  
**Solución**: cambiar a `eclipse-temurin:8-jre` en `test/wiremock/Dockerfile`.

---

## 9. Plan del taller CI/CD

### Duración: 2 horas

---

### Bloque 1 — Fundamentos (30 minutos)

**Objetivo**: entender qué es CI/CD y por qué importa.

#### Teoría (15 min)

**CI (Continuous Integration)** — Integración Continua:
- Cada desarrollador hace push frecuente (mínimo 1 vez al día)
- Un sistema automático compila, prueba y verifica el código
- Si algo falla, el equipo lo sabe en minutos, no en días
- Herramientas: GitHub Actions, Jenkins, GitLab CI, CircleCI

**CD (Continuous Delivery/Deployment)** — Entrega/Despliegue Continuo:
- **Delivery**: el software siempre está listo para desplegar (requiere aprobación manual)
- **Deployment**: el despliegue también es automático
- Herramientas: mismas que CI + ArgoCD, Spinnaker

**Por qué importa**:
- Sin CI/CD: integrar 2 semanas de trabajo puede tomar días
- Con CI/CD: errores detectados en minutos, despliegues en segundos

#### Demo en vivo (15 min)

```bash
# Clonar el repo del lab
git clone <URL_REPO>
cd unir-test-master

# Mostrar la estructura: explicar cada carpeta
ls -la

# Construir la imagen
make build

# Ejecutar la aplicación
make run     # debe imprimir "4"

# Levantar el servidor
make server  # en otra terminal: curl http://localhost:5000/calc/add/5/3
```

---

### Bloque 2 — Pruebas automatizadas (40 minutos)

**Objetivo**: ejecutar cada tipo de prueba y entender qué cubre cada una.

#### Ejercicio guiado (40 min)

```bash
# 1. Pruebas unitarias (5 min)
make test-unit
open results/unit_result.html
open results/coverage/index.html
# Discutir: ¿qué cubre? ¿qué falta?

# 2. Pruebas de comportamiento BDD (5 min)
make test-behavior
# Mostrar calculator.feature: lenguaje humano → código ejecutable

# 3. Levantar el frontend y la API juntos
# Terminal 1:
make server
# Terminal 2:
make run-web
# Abrir http://localhost:80 en el navegador
# Hacer operaciones manualmente

# 4. Pruebas de API (10 min)
make test-api
open results/api_result.html
# Mostrar test/rest/api_test.py: peticiones HTTP reales

# 5. Pruebas E2E con Cypress (10 min)
make test-e2e
# Mostrar test/e2e/cypress/screenshots/ — Cypress tomó capturas del navegador!
open results/cypress_result.html

# 6. Análisis estático (10 min)
make pylint
cat results/pylint_result.txt
# Discutir: ¿qué problemas detectó?
```

**Puntos de discusión**:
- ¿Por qué necesitamos distintos tipos de pruebas?
- La pirámide de testing: unitarias (muchas) → integración → E2E (pocas)
- Trade-offs: velocidad vs confianza

---

### Bloque 3 — GitHub Actions (30 minutos)

**Objetivo**: conectar todo a un pipeline real en la nube.

#### Actividad práctica

**Paso 1**: Crear repositorio en GitHub y hacer push
```bash
git remote add origin https://github.com/TU_USUARIO/lab-cicd.git
git push -u origin main
```

**Paso 2**: Crear `.github/workflows/pipeline.yml` (ver sección 10)

**Paso 3**: Hacer un cambio, commit y push — observar el pipeline correr en GitHub.

**Paso 4**: Introducir un bug intencional y ver cómo el pipeline falla:
```python
# En app/calc.py, cambiar:
return x + y
# Por:
return x + y + 1   # bug intencional
```
```bash
git add app/calc.py
git commit -m "bug: add returns wrong result"
git push
# Ver cómo el pipeline de pruebas detecta el error
```

**Paso 5**: Corregir el bug, push, ver pipeline verde.

---

### Bloque 4 — Despliegue en la nube (20 minutos)

**Objetivo**: ver el flujo completo de despliegue automático.

Ver sección 11 para opciones de despliegue.

---

## 10. GitHub Actions

### Pipeline completo recomendado

Crear el archivo `.github/workflows/pipeline.yml`:

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  # ─────────────────────────────────────────
  # JOB 1: Construcción de la imagen
  # ─────────────────────────────────────────
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout código
        uses: actions/checkout@v4

      - name: Construir imagen Docker
        run: docker build -t calculator-app .

      - name: Guardar imagen para otros jobs
        run: docker save calculator-app | gzip > calculator-app.tar.gz

      - name: Subir imagen como artefacto
        uses: actions/upload-artifact@v4
        with:
          name: docker-image
          path: calculator-app.tar.gz

  # ─────────────────────────────────────────
  # JOB 2: Pruebas unitarias
  # ─────────────────────────────────────────
  test-unit:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - name: Descargar imagen Docker
        uses: actions/download-artifact@v4
        with:
          name: docker-image

      - name: Cargar imagen Docker
        run: docker load < calculator-app.tar.gz

      - name: Ejecutar pruebas unitarias
        run: make test-unit

      - name: Publicar resultados de pruebas
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: unit-test-results
          path: results/

  # ─────────────────────────────────────────
  # JOB 3: Pruebas de comportamiento (BDD)
  # ─────────────────────────────────────────
  test-behavior:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - name: Descargar imagen Docker
        uses: actions/download-artifact@v4
        with:
          name: docker-image

      - name: Cargar imagen Docker
        run: docker load < calculator-app.tar.gz

      - name: Ejecutar pruebas de comportamiento
        run: make test-behavior

  # ─────────────────────────────────────────
  # JOB 4: Pruebas de API
  # ─────────────────────────────────────────
  test-api:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - name: Descargar imagen Docker
        uses: actions/download-artifact@v4
        with:
          name: docker-image

      - name: Cargar imagen Docker
        run: docker load < calculator-app.tar.gz

      - name: Ejecutar pruebas de API
        run: make test-api

      - name: Publicar resultados
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: api-test-results
          path: results/

  # ─────────────────────────────────────────
  # JOB 5: Análisis estático (Pylint)
  # ─────────────────────────────────────────
  lint:
    runs-on: ubuntu-latest
    needs: build
    steps:
      - uses: actions/checkout@v4

      - name: Descargar imagen Docker
        uses: actions/download-artifact@v4
        with:
          name: docker-image

      - name: Cargar imagen Docker
        run: docker load < calculator-app.tar.gz

      - name: Ejecutar pylint
        run: make pylint

  # ─────────────────────────────────────────
  # JOB 6: Despliegue (solo en main)
  # ─────────────────────────────────────────
  deploy:
    runs-on: ubuntu-latest
    needs: [test-unit, test-behavior, test-api, lint]
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - name: Login a Docker Hub (o GHCR)
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Build y push de imagen de producción
        uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/calculator-app:latest

      # Elegir UNA de las siguientes opciones de despliegue:
      # Ver sección 11 para detalles de cada opción
```

### Explicación del pipeline

```
push a main/develop
        │
        ▼
   [build] ─────────────────────────────┐
        │                               │
        ▼ (en paralelo)                 │
  ┌──────────┬──────────┬──────────┐    │
  │test-unit │test-beh  │test-api  │    │
  │          │          │          │    │
  │  lint    │          │          │    │
  └──────┬───┴──────────┴──────────┘    │
         │ (todos deben pasar)          │
         ▼                              │
      [deploy]  ← solo si branch=main   │
         │                              │
         ▼                              │
    Cloud Run / VPS / GCE ◄─────────────┘
```

**Conceptos clave del YAML**:
- `on:` — cuándo se dispara el pipeline
- `jobs:` — tareas que corren (en paralelo por defecto)
- `needs:` — dependencia entre jobs (secuencial)
- `if:` — condición para ejecutar un job
- `secrets:` — variables secretas configuradas en GitHub (Settings → Secrets)

---

## 11. Despliegue en la nube

### Opción A: VPS con Docker (la más simple)

**Ideal para**: enseñar el concepto, coste bajo, control total.

```bash
# En el VPS (Ubuntu 22.04):
apt install docker.io -y

# El pipeline hace SSH y actualiza el contenedor:
ssh usuario@IP_VPS "
  docker pull TU_USUARIO/calculator-app:latest &&
  docker stop apiserver || true &&
  docker run -d --rm --name apiserver -p 5000:5000 \
    --env FLASK_APP=app/api.py \
    TU_USUARIO/calculator-app:latest flask run --host=0.0.0.0
"
```

**Agregar al job `deploy` del pipeline**:
```yaml
- name: Deploy a VPS
  uses: appleboy/ssh-action@v1
  with:
    host: ${{ secrets.VPS_HOST }}
    username: ${{ secrets.VPS_USER }}
    key: ${{ secrets.VPS_SSH_KEY }}
    script: |
      docker pull ${{ secrets.DOCKER_USERNAME }}/calculator-app:latest
      docker stop apiserver || true
      docker run -d --rm --name apiserver -p 5000:5000 \
        --env FLASK_APP=app/api.py \
        ${{ secrets.DOCKER_USERNAME }}/calculator-app:latest \
        flask run --host=0.0.0.0
```

**Secrets necesarios**: `VPS_HOST`, `VPS_USER`, `VPS_SSH_KEY`, `DOCKER_USERNAME`, `DOCKER_PASSWORD`

---

### Opción B: Google Cloud Run (serverless, recomendada para clase)

**Ideal para**: demostrar el concepto "moderno" de CI/CD, escalado automático, sin gestión de servidores.

```yaml
- name: Autenticar con Google Cloud
  uses: google-github-actions/auth@v2
  with:
    credentials_json: ${{ secrets.GCP_SA_KEY }}

- name: Configurar gcloud
  uses: google-github-actions/setup-gcloud@v2

- name: Deploy a Cloud Run
  run: |
    gcloud run deploy calculator-api \
      --image gcr.io/${{ secrets.GCP_PROJECT }}/calculator-app:latest \
      --platform managed \
      --region us-central1 \
      --allow-unauthenticated \
      --port 5000 \
      --set-env-vars FLASK_APP=app/api.py,PYTHONPATH=/opt/calc
```

**Pasos previos**:
1. Crear proyecto en Google Cloud
2. Habilitar Cloud Run API y Container Registry API
3. Crear Service Account con roles: Cloud Run Admin, Storage Admin
4. Descargar clave JSON y guardar en GitHub Secrets como `GCP_SA_KEY`

**Secrets necesarios**: `GCP_SA_KEY`, `GCP_PROJECT`

**Ventaja para la clase**: URL HTTPS pública generada automáticamente, escala a cero (sin coste cuando no hay tráfico).

---

### Opción C: Google Compute Engine (VM)

Similar al VPS pero en Google Cloud. Más control que Cloud Run pero más complejidad.

```yaml
- name: Deploy a Compute Engine
  uses: appleboy/ssh-action@v1
  with:
    host: ${{ secrets.GCE_IP }}
    username: ${{ secrets.GCE_USER }}
    key: ${{ secrets.GCE_SSH_KEY }}
    script: |
      docker pull ${{ secrets.DOCKER_USERNAME }}/calculator-app:latest
      docker stop apiserver || true
      docker run -d --rm --name apiserver -p 5000:5000 \
        --env FLASK_APP=app/api.py \
        ${{ secrets.DOCKER_USERNAME }}/calculator-app:latest \
        flask run --host=0.0.0.0
```

---

## 12. Estado de las herramientas (2025)

| Herramienta | Versión en el repo | Estado actual | Alternativa recomendada |
|-------------|-------------------|---------------|------------------------|
| `python:3.6-slim` | base image | EOL desde 2021 | `python:3.12-slim` |
| `flask==1.1.2` | 1.1.2 | Muy antiguo | `flask==3.0.x` |
| `pytest==5.4.3` | 5.4.3 | Antiguo | `pytest==8.x` |
| `cypress/included:4.9.0` | 4.9.0 | Sin ARM64 | `cypress/included:13.x` |
| `openjdk:8-jre` | 8 | Deprecado en Docker Hub | `eclipse-temurin:11-jre` |
| `sonarqube:8.3.1` | 8.3.1 | Muy antiguo | `sonarqube:10.x-community` |
| `owasp/zap2docker-stable` | latest | Imagen renombrada | `ghcr.io/zaproxy/zaproxy:stable` |
| WireMock 2.27.2 | 2.27.2 | Funcional | WireMock 3.x |
| JMeter 5.4 | 5.4 | Funcional | JMeter 5.6.x |

**Para el taller**: el proyecto funciona tal cual para los comandos principales (`make build`, `make run`, `make server`, `make test-unit`, `make test-behavior`, `make test-api`). Los comandos avanzados (E2E, ZAP, JMeter) requieren actualizar algunas imágenes para ARM64.

**Para producción**: actualizar todas las versiones marcadas como antiguas/EOL.

---

## Apéndice: Comandos de referencia rápida

```bash
# Primer uso
make build

# Desarrollo
make run          # ejecuta calc.py (imprime 4)
make server       # API en localhost:5000
make run-web      # frontend en localhost:80
make interactive  # shell dentro del contenedor

# Testing
make test-unit     # pruebas unitarias + cobertura
make test-behavior # pruebas BDD (Gherkin)
make test-api      # pruebas REST API
make test-e2e      # pruebas de navegador (Cypress)
make pylint        # análisis estático

# Herramientas avanzadas
make build-wiremock && make test-e2e-wiremock
make start-sonar-server && make start-sonar-scanner
make build-jmeter && make jmeter-load
make zap-scan

# Git workflow
git add .
git commit -m "tipo: descripción"
git push origin main  # dispara el pipeline de GitHub Actions
```
