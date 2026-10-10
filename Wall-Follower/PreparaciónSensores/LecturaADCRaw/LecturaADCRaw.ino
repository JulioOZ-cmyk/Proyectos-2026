#include <Arduino.h>

// =====================================================
// ADQUISICION ADC RAW - SENSOR A0
// Arduino Nano / Uno - 16 MHz
//
// Fs = 1000 Hz
// N  = 20000
// Duracion = 20 segundos
//
// Transmision binaria de 16 bits
// =====================================================

const uint8_t SENSOR = A0;

const uint32_t BAUDIOS = 500000;
const uint32_t N_MUESTRAS = 20000;

// Buffer circular: 128 muestras
const uint8_t BUFFER_SIZE = 128;

volatile uint16_t buffer[BUFFER_SIZE];

volatile uint8_t indiceEscritura = 0;
volatile uint8_t indiceLectura = 0;

volatile uint32_t muestrasTomadas = 0;

volatile bool adquisicionTerminada = false;
volatile bool desbordamiento = false;


// =====================================================
// TIMER1 A 1000 Hz
// =====================================================

void configurarTimer1() {

  noInterrupts();

  TCCR1A = 0;
  TCCR1B = 0;
  TCNT1 = 0;

  // 16 MHz / (8 * (1999 + 1)) = 1000 Hz
  OCR1A = 1999;

  TCCR1B |= (1 << WGM12);
  TCCR1B |= (1 << CS11);

  TIMSK1 |= (1 << OCIE1A);

  interrupts();
}


// =====================================================
// INTERRUPCION CADA 1 ms
// =====================================================

ISR(TIMER1_COMPA_vect) {

  if (adquisicionTerminada) {
    return;
  }

  uint8_t siguiente =
      (indiceEscritura + 1) % BUFFER_SIZE;

  // Detectar desbordamiento
  if (siguiente == indiceLectura) {

    desbordamiento = true;
    adquisicionTerminada = true;

    TIMSK1 &= ~(1 << OCIE1A);

    return;
  }

  // Unicamente la lectura RAW
  buffer[indiceEscritura] = analogRead(SENSOR);

  indiceEscritura = siguiente;

  muestrasTomadas++;

  if (muestrasTomadas >= N_MUESTRAS) {

    adquisicionTerminada = true;

    TIMSK1 &= ~(1 << OCIE1A);
  }
}


// =====================================================
// SETUP
// =====================================================

void setup() {

  Serial.begin(BAUDIOS);

  pinMode(SENSOR, INPUT);

  // Esperar a que MATLAB abra el puerto
  Serial.println("LISTO");

  // Esperar comando de inicio
  while (true) {

    if (Serial.available() > 0) {

      char comando = Serial.read();

      if (comando == 'S') {
        break;
      }
    }
  }

  // Comenzar adquisicion
  configurarTimer1();
}


// =====================================================
// LOOP
// =====================================================

void loop() {

  uint16_t lectura;
  bool disponible = false;

  // Extraer muestra del buffer
  noInterrupts();

  if (indiceLectura != indiceEscritura) {

    lectura = buffer[indiceLectura];

    indiceLectura =
        (indiceLectura + 1) % BUFFER_SIZE;

    disponible = true;
  }

  interrupts();

  // Enviar medicion binaria
  if (disponible) {

    Serial.write((uint8_t)(lectura & 0xFF));
    Serial.write((uint8_t)(lectura >> 8));

  }

  // Comprobar finalizacion
  if (adquisicionTerminada) {

    noInterrupts();

    bool bufferVacio =
        (indiceLectura == indiceEscritura);

    bool error =
        desbordamiento;

    interrupts();

    if (bufferVacio) {

      Serial.flush();

      if (error) {
        Serial.println("ERROR");
      }
      else {
        Serial.println("OK");
      }

      while (true) {
        // Esperar reinicio
      }
    }
  }
}