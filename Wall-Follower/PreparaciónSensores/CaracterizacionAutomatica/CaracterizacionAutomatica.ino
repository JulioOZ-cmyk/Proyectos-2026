// ============================================================
// CONFIGURACION
// ============================================================

const int SENSOR = A0;

// Numero de muestras por cada distancia
const int N_MUESTRAS = 100;

// Rango de calibracion
const int DISTANCIA_INICIAL = 20;
const int DISTANCIA_FINAL   = 120;
const int PASO_DISTANCIA    = 5;

// Tiempo disponible para mover la pared
// 10000 ms = 10 segundos
const unsigned long TIEMPO_ESPERA = 10000;


// ============================================================
// VARIABLES
// ============================================================

volatile bool tomarMuestra = false;

bool adquiriendo = false;
bool esperando   = false;
bool terminado   = false;

int contador = 0;

int distancia_mm = DISTANCIA_INICIAL;

double suma  = 0;
double suma2 = 0;

unsigned long tiempoInicioEspera = 0;


// ============================================================
// CONFIGURACION TIMER1
//
// Frecuencia de muestreo = 100 Hz
// Periodo de muestreo    = 10 ms
//
// fCPU = 16 MHz
// Prescaler = 64
//
// 16 MHz / 64 = 250 kHz
//
// Ttick = 4 us
//
// 10 ms / 4 us = 2500 cuentas
//
// OCR1A = 2500 - 1 = 2499
// ============================================================

void configurarTimer1()
{
  cli();

  // Limpiar registros
  TCCR1A = 0;
  TCCR1B = 0;

  // Reiniciar contador
  TCNT1 = 0;

  // Comparacion cada 10 ms
  OCR1A = 2499;

  // Modo CTC
  TCCR1B |= (1 << WGM12);

  // Prescaler = 64
  TCCR1B |= (1 << CS11) | (1 << CS10);

  // Habilitar interrupcion Compare Match A
  TIMSK1 |= (1 << OCIE1A);

  sei();
}


// ============================================================
// INTERRUPCION TIMER1
//
// Se ejecuta cada 10 ms
// ============================================================

ISR(TIMER1_COMPA_vect)
{
  if (adquiriendo)
  {
    tomarMuestra = true;
  }
}


// ============================================================
// INICIAR ESPERA
//
// Da 10 segundos para colocar la pared
// ============================================================

void iniciarEspera()
{
  esperando   = true;
  adquiriendo = false;

  tiempoInicioEspera = millis();

  Serial.println();
  Serial.println("================================");

  Serial.print("Coloque la pared a ");
  Serial.print(distancia_mm);
  Serial.println(" mm");

  Serial.println("Tiene 10 segundos para moverla...");
}


// ============================================================
// INICIAR ADQUISICION
// ============================================================

void iniciarAdquisicion()
{
  esperando = false;

  // Reiniciar acumuladores
  suma  = 0;
  suma2 = 0;

  contador = 0;

  tomarMuestra = false;

  // Activar adquisicion
  adquiriendo = true;

  Serial.print("Midiendo a ");
  Serial.print(distancia_mm);
  Serial.println(" mm...");
}


// ============================================================
// SIGUIENTE DISTANCIA
// ============================================================

void siguienteDistancia()
{
  distancia_mm += PASO_DISTANCIA;
}


// ============================================================
// SETUP
// ============================================================

void setup()
{
  Serial.begin(115200);

  pinMode(SENSOR, INPUT);

  configurarTimer1();

  Serial.println();
  Serial.println("========================================");
  Serial.println("CALIBRACION AUTOMATICA DEL SENSOR");
  Serial.println("========================================");

  Serial.print("Sensor: A");
  Serial.println(SENSOR - A0);

  Serial.print("Rango: ");
  Serial.print(DISTANCIA_INICIAL);
  Serial.print(" - ");
  Serial.print(DISTANCIA_FINAL);
  Serial.println(" mm");

  Serial.print("Paso: ");
  Serial.print(PASO_DISTANCIA);
  Serial.println(" mm");

  Serial.print("Muestras por distancia: ");
  Serial.println(N_MUESTRAS);

  Serial.print("Frecuencia de muestreo: ");
  Serial.println("100 Hz");

  Serial.print("Tiempo entre posiciones: ");
  Serial.println("10 segundos");

  Serial.println();

  Serial.println(
    "Distancia_mm\tADC_promedio\tDesviacion"
  );

  // Primera medicion: 20 mm
  iniciarEspera();
}


// ============================================================
// LOOP
// ============================================================

void loop()
{
  // ==========================================================
  // 1. ESPERA DE 10 SEGUNDOS
  // ==========================================================

  if (esperando)
  {
    if (millis() - tiempoInicioEspera >= TIEMPO_ESPERA)
    {
      iniciarAdquisicion();
    }
  }


  // ==========================================================
  // 2. ADQUISICION A 100 Hz
  // ==========================================================

  if (tomarMuestra && adquiriendo)
  {
    tomarMuestra = false;


    // --------------------------------------------------------
    // Leer ADC
    // --------------------------------------------------------

    int adc = analogRead(SENSOR);


    // --------------------------------------------------------
    // Acumular
    // --------------------------------------------------------

    suma += adc;

    suma2 += (double)adc * adc;

    contador++;


    // ========================================================
    // 3. ¿YA TENEMOS LAS 100 MUESTRAS?
    // ========================================================

    if (contador >= N_MUESTRAS)
    {
      adquiriendo = false;


      // ======================================================
      // PROMEDIO
      // ======================================================

      float promedio = suma / N_MUESTRAS;


      // ======================================================
      // VARIANZA
      // ======================================================

      float varianza =
        suma2 / N_MUESTRAS
        - promedio * promedio;

      // Evitar valores negativos pequeños
      // debido al redondeo numerico
      if (varianza < 0)
      {
        varianza = 0;
      }


      // ======================================================
      // DESVIACION ESTANDAR
      // ======================================================

      float desviacion = sqrt(varianza);


      // ======================================================
      // 4. ENVIAR RESULTADO A MATLAB
      //
      // Formato:
      //
      // DATA,distancia,ADC_promedio,desviacion
      //
      // Ejemplo:
      //
      // DATA,50,487.32,1.24
      // ======================================================

      Serial.print("DATA,");

      Serial.print(distancia_mm);

      Serial.print(",");

      Serial.print(promedio, 2);

      Serial.print(",");

      Serial.println(desviacion, 2);


      // ======================================================
      // 5. PASAR A LA SIGUIENTE DISTANCIA
      // ======================================================

      siguienteDistancia();


      // ======================================================
      // 6. ¿QUEDAN DISTANCIAS?
      // ======================================================

      if (distancia_mm <= DISTANCIA_FINAL)
      {
        iniciarEspera();
      }

      else
      {
        // ====================================================
        // CALIBRACION TERMINADA
        // ====================================================

        terminado = true;

        esperando   = false;
        adquiriendo = false;

        Serial.println();
        Serial.println(
          "========================================"
        );

        Serial.println(
          "CALIBRACION FINALIZADA"
        );

        Serial.println(
          "Rango medido: 20 - 120 mm"
        );

        // MATLAB detecta FIN y termina la recepcion
        Serial.println("FIN");

        Serial.println(
          "========================================"
        );
      }
    }
  }
}