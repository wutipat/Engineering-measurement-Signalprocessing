%% dual_mic_tdoa_realtime.m
%  Real-time dual-microphone bandpass filter + time-delay estimation
%  using GCC-PHAT (Generalized Cross-Correlation with Phase Transform).
%
%  Requirements:
%    - MATLAB R2018b+ with Audio Toolbox
%    - A stereo audio input device (two mics on channels 1 & 2)
%
%  Usage:
%    dual_mic_tdoa_realtime          % default settings
%    dual_mic_tdoa_realtime(params)  % custom params (see PARAMETERS below)

function dual_mic_tdoa_realtime(userParams)

% -------------------------------------------------------------------------
% PARAMETERS  (edit here or pass a struct)
% -------------------------------------------------------------------------
p.fs            = 44100;   % sample rate (Hz)
p.frameSize     = 1024;    % samples per processing frame
p.bpLow         = 300;     % bandpass lower cutoff (Hz)
p.bpHigh        = 3400;    % bandpass upper cutoff (Hz)
p.bpOrder       = 6;       % Butterworth filter order
p.micDistance   = 0.20;    % distance between mics (metres)
p.speedOfSound  = 343;     % m/s at ~20°C
p.deviceID      = 0;       % 0 = system default; use audiodevinfo() to list
p.runSeconds    = 60;      % total run time (seconds); Inf = run until Ctrl-C
p.plotLive      = true;    % show live GCC plot
p.smoothAlpha   = 0.3;     % EMA smoothing for displayed delay (0=no smooth)
p.windowType    = 'hann';  % frame window: 'hann' | 'hamming' | 'rect'

% Merge user overrides
if nargin > 0 && isstruct(userParams)
    fields = fieldnames(userParams);
    for k = 1:numel(fields)
        p.(fields{k}) = userParams.(fields{k});
    end
end

% -------------------------------------------------------------------------
% DERIVED CONSTANTS
% -------------------------------------------------------------------------
maxDelaySamples = round(p.micDistance / p.speedOfSound * p.fs) + 1;
maxDelayMs      = maxDelaySamples / p.fs * 1000;
totalFrames     = ceil(p.runSeconds * p.fs / p.frameSize);
nFFT            = 2 * p.frameSize;        % zero-pad for linear correlation

fprintf('=== Dual-Mic TDOA  |  fs=%d Hz  |  frame=%d smp  |  BPF=%d-%d Hz ===\n', ...
        p.fs, p.frameSize, p.bpLow, p.bpHigh);
fprintf('Max physical delay: ±%.2f ms  (d=%.2f m)\n\n', maxDelayMs, p.micDistance);

% -------------------------------------------------------------------------
% DESIGN BANDPASS FILTER (zero-phase IIR via filtfilt, or causal via filter)
% -------------------------------------------------------------------------
Wn  = [p.bpLow, p.bpHigh] / (p.fs/2);          % normalised cutoffs
[b, a] = butter(p.bpOrder, Wn, 'bandpass');

% Initial filter states (for streaming, avoid discontinuity between frames)
zi1 = zeros(max(length(a),length(b))-1, 1);
zi2 = zeros(max(length(a),length(b))-1, 1);

% -------------------------------------------------------------------------
% FRAME WINDOW
% -------------------------------------------------------------------------
switch lower(p.windowType)
    case 'hann',    win = hann(p.frameSize);
    case 'hamming', win = hamming(p.frameSize);
    otherwise,      win = ones(p.frameSize,1);
end

% -------------------------------------------------------------------------
% AUDIO READER
% -------------------------------------------------------------------------
if p.deviceID == 0
    reader = audioDeviceReader(p.fs, p.frameSize, 'NumChannels', 2);
else
    reader = audioDeviceReader(p.fs, p.frameSize, ...
                               'NumChannels', 2, ...
                               'Device', p.deviceID);
end
setup(reader);

% -------------------------------------------------------------------------
% LIVE PLOT
% -------------------------------------------------------------------------
if p.plotLive
    hFig = figure('Name','GCC-PHAT  –  Real-time TDOA', ...
                  'NumberTitle','off','Color',[0.12 0.12 0.12]);
    lagAxis = (-p.frameSize+1 : p.frameSize-1) / p.fs * 1000;  % ms

    subplot(2,1,1);
    hGCC = plot(lagAxis, zeros(1,nFFT-1), 'c', 'LineWidth',1.2);
    hold on;
    hPeak = plot(0, 0, 'ro', 'MarkerSize',8, 'MarkerFaceColor','r');
    xlabel('Lag (ms)'); ylabel('GCC-PHAT'); title('Cross-correlation');
    xlim([-maxDelayMs*2, maxDelayMs*2]);
    set(gca,'Color',[0.15 0.15 0.15],'XColor','w','YColor','w','GridColor','w');
    grid on;

    subplot(2,1,2);
    hDelayLine = animatedline('Color','y','MaximumNumPoints',300,'LineWidth',1.5);
    xlabel('Frame'); ylabel('Delay (ms)'); title('TDOA over time');
    ylim([-maxDelayMs*1.5, maxDelayMs*1.5]);
    yline(0,'--w','Alpha',0.4);
    set(gca,'Color',[0.15 0.15 0.15],'XColor','w','YColor','w','GridColor','w');
    grid on;
    drawnow;
end

% -------------------------------------------------------------------------
% MAIN LOOP
% -------------------------------------------------------------------------
delaySmooth = 0;
frameCount  = 0;

fprintf('%-8s  %-12s  %-12s  %-12s\n', 'Frame', 'Delay (ms)', 'Delay (smp)', 'Angle (deg)');
fprintf('%s\n', repmat('-',1,50));

try
    while frameCount < totalFrames
        % --- Read stereo frame -------------------------------------------
        audioData = reader();            % [frameSize x 2]
        x1 = double(audioData(:,1));
        x2 = double(audioData(:,2));

        % --- Apply frame window ------------------------------------------
        x1w = x1 .* win;
        x2w = x2 .* win;

        % --- Bandpass filter (streaming, preserve state) -----------------
        [x1f, zi1] = filter(b, a, x1w, zi1);
        [x2f, zi2] = filter(b, a, x2w, zi2);

        % --- GCC-PHAT -----------------------------------------------------
        [tdoa_smp, gcc, lagAxis_smp] = gcc_phat(x1f, x2f, nFFT, maxDelaySamples);

        % --- Convert to physical units ------------------------------------
        tdoa_ms  = tdoa_smp / p.fs * 1000;
        sinTheta = tdoa_smp / p.fs * p.speedOfSound / p.micDistance;
        sinTheta = max(-1, min(1, sinTheta));  % clamp for asin
        angle_deg = asind(sinTheta);

        % --- EMA smoothing ------------------------------------------------
        delaySmooth = p.smoothAlpha * tdoa_ms + (1-p.smoothAlpha) * delaySmooth;

        frameCount = frameCount + 1;

        % --- Console output (every 10 frames) ----------------------------
        if mod(frameCount, 10) == 0
            fprintf('%-8d  %-12.3f  %-12d  %-12.1f\n', ...
                    frameCount, tdoa_ms, tdoa_smp, angle_deg);
        end

        % --- Update live plot --------------------------------------------
        if p.plotLive && ishandle(hFig)
            lagMs = lagAxis_smp / p.fs * 1000;
            set(hGCC,  'XData', lagMs, 'YData', gcc);
            set(hPeak, 'XData', tdoa_ms, 'YData', gcc(lagAxis_smp==tdoa_smp));
            addpoints(hDelayLine, frameCount, delaySmooth);
            drawnow limitrate;
        end
    end

catch ME
    if strcmp(ME.identifier,'MATLAB:class:InvalidHandle')
        fprintf('\nPlot window closed – stopping.\n');
    else
        rethrow(ME);
    end
end

% -------------------------------------------------------------------------
% CLEANUP
% -------------------------------------------------------------------------
release(reader);
fprintf('\nDone.  %d frames processed.\n', frameCount);

end  % function dual_mic_tdoa_realtime


% =========================================================================
%  HELPER: GCC-PHAT
%  Inputs:
%    x1, x2        – filtered audio frames (column vectors)
%    nFFT          – FFT length (should be >= 2*length(x1))
%    maxDelay      – search window in samples (improves robustness)
%  Outputs:
%    tdoa_smp      – estimated time delay in samples
%    gcc           – GCC-PHAT function (for plotting)
%    lags          – corresponding lag vector (samples)
% =========================================================================
function [tdoa_smp, gcc, lags] = gcc_phat(x1, x2, nFFT, maxDelay)

    X1 = fft(x1, nFFT);
    X2 = fft(x2, nFFT);

    % Cross-power spectrum
    G  = X1 .* conj(X2);

    % PHAT weighting: normalise by magnitude → pure phase info
    G  = G ./ (abs(G) + 1e-10);

    % Inverse FFT → correlation
    cc = real(ifft(G, nFFT));

    % Reorder to centred lag form: [-(N/2-1) … 0 … N/2]
    cc   = fftshift(cc);
    N    = nFFT;
    lags = (-(N/2) : (N/2)-1)';   % column vector of lag indices

    % --- Restrict search to physically plausible delays ------------------
    searchMask        = abs(lags) <= maxDelay;
    cc_search         = cc;
    cc_search(~searchMask) = 0;

    % Peak-picking
    [~, peakIdx] = max(cc_search);
    tdoa_smp     = lags(peakIdx);

    gcc  = cc_search;
    lags = lags;

end
