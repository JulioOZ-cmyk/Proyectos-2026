%% ============================================================
% ADQUISICION ADC RAW - SENSOR A0
%
% Frecuencia: 1000 Hz
% Muestras: 20000
% Duracion: 20 segundos
%
% Comunicacion binaria Arduino - MATLAB
% ============================================================

clc;
clear;
close all;


%% ============================================================
% 1. CONFIGURACION
% ============================================================

puerto = "COM3";

baud = 500000;

Fs = 1000;

N = 20000;


fprintf("====================================\n");
fprintf("ADQUISICION SENSOR A0\n");
fprintf("====================================\n");

fprintf("Frecuencia: %d Hz\n", Fs);
fprintf("Muestras: %d\n", N);
fprintf("Duracion: %.2f segundos\n", N/Fs);
fprintf("Resolucion FFT: %.4f Hz\n", Fs/N);
fprintf("Nyquist: %.0f Hz\n\n", Fs/2);


%% ============================================================
% 2. CONEXION SERIAL
% ============================================================

% Cerrar conexiones anteriores
puertosAnteriores = serialportfind;

if ~isempty(puertosAnteriores)
    delete(puertosAnteriores);
end

% Abrir puerto
arduino = serialport(puerto, baud);

configureTerminator(arduino, "LF");

arduino.Timeout = 10;

fprintf("Esperando Arduino...\n");


%% ============================================================
% 3. SINCRONIZACION
% ============================================================

% Esperar confirmacion
while true

    try

        linea = strtrim(string(readline(arduino)));

        if linea == "LISTO"

            fprintf("Arduino preparado.\n");

            break;
        end

    catch

        fprintf("Esperando conexion...\n");

    end

end


% Dar orden de inicio
fprintf("Iniciando adquisicion...\n\n");

write(arduino, uint8('S'), "uint8");


%% ============================================================
% 4. RECIBIR DATOS BINARIOS
% ============================================================

% Cada muestra ocupa 2 bytes
bytesEsperados = N * 2;

datosBinarios = zeros(bytesEsperados, 1, "uint8");

bytesRecibidos = 0;

tic;

while bytesRecibidos < bytesEsperados

    disponibles = arduino.NumBytesAvailable;

    if disponibles > 0

        cantidad = min( ...
            disponibles, ...
            bytesEsperados - bytesRecibidos);

        bloque = read(arduino, cantidad, "uint8");

        bloque = bloque(:);

        indices = ...
            bytesRecibidos + (1:numel(bloque));

        datosBinarios(indices) = bloque;

        bytesRecibidos = ...
            bytesRecibidos + numel(bloque);

    else

        pause(0.001);

    end


    % Mostrar progreso
    if toc > 30

        clear arduino;

        error("Tiempo de espera agotado.");

    end

end


fprintf("Bytes recibidos: %d/%d\n", ...
    bytesRecibidos, bytesEsperados);


%% ============================================================
% 5. COMPROBAR ESTADO FINAL
% ============================================================

% Los 40000 bytes ya se han recibido.
% El siguiente mensaje es texto.

estado = strtrim(string(readline(arduino)));

fprintf("Estado Arduino: %s\n", estado);

clear arduino;


if estado ~= "OK"

    error("Arduino detecto un error de adquisicion.");

end


%% ============================================================
% 6. RECONSTRUIR MEDICIONES ADC
% ============================================================

% Arduino transmite primero el byte bajo
% y despues el byte alto.

byteBajo = uint16(datosBinarios(1:2:end));

byteAlto = uint16(datosBinarios(2:2:end));

adcRaw = double( ...
    byteBajo + bitshift(byteAlto, 8));


%% ============================================================
% 7. VERIFICAR DATOS
% ============================================================

if numel(adcRaw) ~= N

    error("Numero incorrecto de muestras.");

end

if any(adcRaw > 1023)

    error("Se recibieron valores ADC invalidos.");

end


fprintf("\n====================================\n");
fprintf("ESTADISTICAS\n");
fprintf("====================================\n");

fprintf("Muestras: %d\n", numel(adcRaw));
fprintf("Media ADC: %.4f\n", mean(adcRaw));
fprintf("Desviacion: %.4f\n", std(adcRaw));
fprintf("Minimo: %.0f\n", min(adcRaw));
fprintf("Maximo: %.0f\n", max(adcRaw));


%% ============================================================
% 8. VECTOR TEMPORAL
% ============================================================

t = (0:N-1)' / Fs;


%% ============================================================
% 9. GRAFICA TEMPORAL
% ============================================================

figure('Name', 'ADC RAW - Sensor A0');

plot(t, adcRaw);

grid on;

xlabel('Tiempo [s]');
ylabel('ADC RAW');

title('Mediciones originales del sensor A0');

xlim([0 20]);


%% ============================================================
% 10. GUARDAR MEDICIONES
% ============================================================

save('ADC_RAW_A0_20s.mat', ...
    'adcRaw', 't', 'Fs');

tabla = table(t, adcRaw, ...
    'VariableNames', ...
    {'Tiempo_s', 'ADC_RAW'});

writetable(tabla, 'ADC_RAW_A0_20s.csv');


%% ============================================================
% 11. SIGNAL ANALYZER
% ============================================================

signalAnalyzer(adcRaw, "SampleRate", Fs);