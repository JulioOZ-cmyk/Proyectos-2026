%% ============================================================
% ANALISIS COMPLETO DEL FILTRO IIR BUTTERWORTH
%
% Tipo: Pasa-bajos Butterworth
% Orden: 4
% Frecuencia de corte: 20 Hz
% Frecuencia de muestreo: 1000 Hz
%
% Analisis:
%  1. Diseño del filtro
%  2. Coeficientes SOS
%  3. Filtrado de datos experimentales
%  4. Reduccion del ruido
%  5. Respuesta en frecuencia
%  6. Atenuacion del ruido
%  7. Retardo de grupo
%  8. Respuesta al escalon
%  9. Tiempo de respuesta
% 10. Tiempo de establecimiento
% 11. Sobreimpulso
%
% Requiere:
%   adcRaw en el Workspace
%   Signal Processing Toolbox
%
%% ============================================================

clc;
close all;

%% ============================================================
% 1. PARAMETROS
%% ============================================================

Fs = 1000;
Fc = 20;
orden = 4;

% Datos originales del sensor
x = double(adcRaw(:));

% Vector de tiempo
t = (0:length(x)-1)' / Fs;

fprintf('\n====================================\n');
fprintf(' ANALISIS DEL FILTRO BUTTERWORTH\n');
fprintf('====================================\n');

fprintf('Orden: %d\n', orden);
fprintf('Frecuencia de corte: %.2f Hz\n', Fc);
fprintf('Frecuencia de muestreo: %.2f Hz\n', Fs);
fprintf('Numero de muestras: %d\n', length(x));


%% ============================================================
% 2. DISEÑO DEL FILTRO
%% ============================================================

% Diseñar filtro Butterworth
[z, p, k] = butter(orden, Fc/(Fs/2), 'low');

% Convertir a secciones de segundo orden
[sos, g] = zp2sos(z, p, k);

format long g;

fprintf('\n========== COEFICIENTES ==========\n');

disp('Matriz SOS:');
disp(sos);

fprintf('Ganancia global: %.15f\n', g);

% Incorporar la ganancia global al primer biquad
% para disponer de una matriz lista para Arduino.

sosArduino = sos;

sosArduino(1,1:3) = ...
    g * sosArduino(1,1:3);

disp('Matriz SOS con ganancia incorporada:');
disp(sosArduino);


%% ============================================================
% 3. FILTRADO CAUSAL
%% ============================================================

% Filtrado causal mediante dos biquads
% La ganancia ya esta incorporada.

y = x;

for i = 1:size(sosArduino,1)

    b = sosArduino(i,1:3);
    a = sosArduino(i,4:6);

    y = filter(b, a, y);

end


%% ============================================================
% 4. COMPARACION DE SEÑALES
%% ============================================================

figure('Name','Señal original y filtrada');

plot(t, x, ...
    'Color',[0.75 0.75 0.75]);

hold on;

plot(t, y, ...
    'b','LineWidth',1.4);

xlabel('Tiempo (s)');
ylabel('ADC');

title('Señal original vs Butterworth');

legend('Original','Butterworth');

grid on;

% Intervalo de visualizacion
xlim([5 7]);


%% ============================================================
% 5. REDUCCION DEL RUIDO
%% ============================================================

% Seleccionar intervalo de pared inmovil

inicio = 5;
fin = 7;

idx = t >= inicio & t <= fin;

stdOriginal = std(x(idx));

stdFiltrado = std(y(idx));

reduccion = ...
    100 * (1 - stdFiltrado/stdOriginal);

fprintf('\n========== ANALISIS DEL RUIDO ==========\n');

fprintf('Desviacion original: %.4f ADC\n', ...
    stdOriginal);

fprintf('Desviacion filtrada: %.4f ADC\n', ...
    stdFiltrado);

fprintf('Reduccion de desviacion: %.2f %%\n', ...
    reduccion);


%% ============================================================
% 6. RESPUESTA EN FRECUENCIA
%% ============================================================

f = linspace(0, Fs/2, 4096);

% Inicializar respuesta total
H = ones(size(f));

% Multiplicar respuestas de los biquads
for i = 1:size(sosArduino,1)

    Hi = freqz( ...
        sosArduino(i,1:3), ...
        sosArduino(i,4:6), ...
        f, Fs);

    H = H .* Hi(:).';

end

magnitudDB = ...
    20*log10(max(abs(H),eps));

figure('Name','Respuesta en frecuencia');

plot(f, magnitudDB, ...
    'LineWidth',1.5);

xlabel('Frecuencia (Hz)');
ylabel('Magnitud (dB)');

title('Respuesta en frecuencia del Butterworth');

grid on;

xlim([0 150]);


%% ============================================================
% 7. ATENUACION DE FRECUENCIAS DE RUIDO
%% ============================================================

% Frecuencias identificadas experimentalmente

frecuenciasRuido = [53; 106; 420; 473];

Hruido = ones(size(frecuenciasRuido));

for i = 1:size(sosArduino,1)

    Hi = freqz( ...
        sosArduino(i,1:3), ...
        sosArduino(i,4:6), ...
        frecuenciasRuido, Fs);

    Hruido = Hruido .* Hi(:);

end

gananciasDB = ...
    20*log10(abs(Hruido));

tablaRuido = table( ...
    frecuenciasRuido, ...
    gananciasDB, ...
    'VariableNames', ...
    {'Frecuencia_Hz','Ganancia_dB'});

fprintf('\n========== ATENUACION ==========\n');

disp(tablaRuido);


%% ============================================================
% 8. RETARDO DE GRUPO
%% ============================================================

% Evaluar retardo entre 0 y 40 Hz

fGrupo = linspace(0,40,4001);

HGrupo = ones(size(fGrupo));

for i = 1:size(sosArduino,1)

    Hi = freqz( ...
        sosArduino(i,1:3), ...
        sosArduino(i,4:6), ...
        fGrupo, Fs);

    HGrupo = HGrupo .* Hi(:).';

end

% Desenvolver fase
fase = unwrap(angle(HGrupo));

% Retardo de grupo:
% tau = -(1/2*pi) * d(fase)/df

retardo_s = ...
    -gradient(fase,fGrupo)/(2*pi);

% Convertir a milisegundos
retardo_ms = retardo_s * 1000;

figure('Name','Retardo de grupo');

plot(fGrupo,retardo_ms, ...
    'LineWidth',1.5);

xlabel('Frecuencia (Hz)');
ylabel('Retardo de grupo (ms)');

title('Retardo de grupo del Butterworth');

grid on;

xlim([0 40]);


%% ============================================================
% 9. RETARDO EN FRECUENCIAS ESPECIFICAS
%% ============================================================

frecuenciasEvaluar = [0 5 10 15 20];

retardos = interp1( ...
    fGrupo, ...
    retardo_ms, ...
    frecuenciasEvaluar);

tablaRetardo = table( ...
    frecuenciasEvaluar(:), ...
    retardos(:), ...
    'VariableNames', ...
    {'Frecuencia_Hz','Retardo_ms'});

fprintf('\n========== RETARDO DE GRUPO ==========\n');

disp(tablaRetardo);

% Retardo maximo en la banda de 0 a 20 Hz

idxBanda = fGrupo <= 20;

retardoMaximo = max(retardo_ms(idxBanda));

fprintf('Retardo maximo entre 0 y 20 Hz: %.3f ms\n', ...
    retardoMaximo);


%% ============================================================
% 10. RESPUESTA AL ESCALON
%% ============================================================

% Simular cambio instantaneo de 400 a 450 ADC

duracion = 0.5;

tEsc = (0:1/Fs:duracion)';

instanteCambio = 0.1;

valorInicial = 400;
valorFinal = 450;

entrada = ...
    valorInicial * ones(size(tEsc));

entrada(tEsc >= instanteCambio) = ...
    valorFinal;

% Trabajar con la variacion respecto al
% valor inicial para evitar un transitorio
% artificial al comenzar la simulacion.

variacion = entrada - valorInicial;

salida = variacion;

for i = 1:size(sosArduino,1)

    salida = filter( ...
        sosArduino(i,1:3), ...
        sosArduino(i,4:6), ...
        salida);

end

salida = salida + valorInicial;


%% ============================================================
% 11. TIEMPOS DE RESPUESTA
%% ============================================================

amplitud = valorFinal - valorInicial;

nivel50 = valorInicial + 0.50*amplitud;

nivel90 = valorInicial + 0.90*amplitud;

nivel98 = valorInicial + 0.98*amplitud;

% Primera muestra posterior al escalon

idxCambio = find( ...
    tEsc >= instanteCambio,1,'first');

% Extraer respuesta posterior al cambio

tPost = tEsc(idxCambio:end);

yPost = salida(idxCambio:end);

% Primer cruce de cada nivel

idx50 = find(yPost >= nivel50,1,'first');

idx90 = find(yPost >= nivel90,1,'first');

idx98 = find(yPost >= nivel98,1,'first');

% Calcular tiempos

tiempo50 = NaN;
tiempo90 = NaN;
tiempo98 = NaN;

if ~isempty(idx50)

    tiempo50 = ...
        (tPost(idx50)-instanteCambio)*1000;

end

if ~isempty(idx90)

    tiempo90 = ...
        (tPost(idx90)-instanteCambio)*1000;

end

if ~isempty(idx98)

    tiempo98 = ...
        (tPost(idx98)-instanteCambio)*1000;

end


%% ============================================================
% 12. TIEMPO DE ESTABLECIMIENTO
%% ============================================================

% Banda de tolerancia del 2 %
% respecto a la amplitud del escalon

tolerancia = 0.02*abs(amplitud);

limiteInferior = valorFinal-tolerancia;

limiteSuperior = valorFinal+tolerancia;

% Identificar muestras fuera de la banda

fueraBanda = ...
    (yPost < limiteInferior) | ...
    (yPost > limiteSuperior);

ultimoFuera = find( ...
    fueraBanda,1,'last');

if isempty(ultimoFuera)

    tiempoEstablecimiento = 0;

elseif ultimoFuera < length(yPost)

    tiempoEstablecimiento = ...
        (tPost(ultimoFuera+1)-instanteCambio)*1000;

else

    % No se establecio durante la simulacion
    tiempoEstablecimiento = NaN;

end


%% ============================================================
% 13. SOBREIMPULSO
%% ============================================================

valorMaximo = max(yPost);

sobreimpulso = max(0, ...
    (valorMaximo-valorFinal)/abs(amplitud)*100);


%% ============================================================
% 14. GRAFICA DE RESPUESTA AL ESCALON
%% ============================================================

figure('Name','Respuesta al escalon');

plot(tEsc*1000,entrada, ...
    'k--','LineWidth',1.2);

hold on;

plot(tEsc*1000,salida, ...
    'b','LineWidth',1.5);

yline(nivel50,'--','50%');

yline(nivel90,'--','90%');

yline(nivel98,'--','98%');

% Banda de establecimiento
yline(limiteInferior,':','Limite inferior');
yline(limiteSuperior,':','Limite superior');

xlabel('Tiempo (ms)');
ylabel('ADC');

title('Respuesta al escalon del Butterworth');

legend('Entrada','Salida filtrada', ...
    'Location','best');

grid on;

xlim([80 250]);


%% ============================================================
% 15. MOSTRAR RESULTADOS TEMPORALES
%% ============================================================

fprintf('\n========== RESPUESTA TEMPORAL ==========\n');

fprintf('Tiempo al 50%%: %.3f ms\n', ...
    tiempo50);

fprintf('Tiempo al 90%%: %.3f ms\n', ...
    tiempo90);

fprintf('Primer cruce del 98%%: %.3f ms\n', ...
    tiempo98);

fprintf('Tiempo de establecimiento (2%%): %.3f ms\n', ...
    tiempoEstablecimiento);

fprintf('Sobreimpulso: %.3f %%\n', ...
    sobreimpulso);


%% ============================================================
% 16. RESUMEN GENERAL
%% ============================================================

fprintf('\n====================================\n');
fprintf(' RESUMEN GENERAL\n');
fprintf('====================================\n');

fprintf('Filtro: IIR Butterworth\n');

fprintf('Orden: %d\n',orden);

fprintf('Frecuencia de corte: %.2f Hz\n',Fc);

fprintf('Frecuencia de muestreo: %.2f Hz\n',Fs);

fprintf('Numero de biquads: %d\n', ...
    size(sosArduino,1));

fprintf('\n--- Ruido ---\n');

fprintf('Desviacion original: %.4f ADC\n', ...
    stdOriginal);

fprintf('Desviacion filtrada: %.4f ADC\n', ...
    stdFiltrado);

fprintf('Reduccion: %.2f %%\n',reduccion);

fprintf('\n--- Retardo ---\n');

fprintf('Retardo maximo (0-20 Hz): %.3f ms\n', ...
    retardoMaximo);

fprintf('\n--- Respuesta al escalon ---\n');

fprintf('Tiempo al 50%%: %.3f ms\n',tiempo50);

fprintf('Tiempo al 90%%: %.3f ms\n',tiempo90);

fprintf('Primer cruce del 98%%: %.3f ms\n',tiempo98);

fprintf('Tiempo de establecimiento: %.3f ms\n', ...
    tiempoEstablecimiento);

fprintf('Sobreimpulso: %.3f %%\n',sobreimpulso);


%% ============================================================
% 17. GUARDAR RESULTADOS
%% ============================================================

save('AnalisisButterworth.mat', ...
    'Fs', ...
    'Fc', ...
    'orden', ...
    'sosArduino', ...
    'x', ...
    'y', ...
    'stdOriginal', ...
    'stdFiltrado', ...
    'reduccion', ...
    'retardoMaximo', ...
    'tiempo50', ...
    'tiempo90', ...
    'tiempo98', ...
    'tiempoEstablecimiento', ...
    'sobreimpulso');

fprintf('\nResultados guardados en AnalisisButterworth.mat\n');