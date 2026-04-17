%% list_audio_devices.m
%  Run this first to find the correct Device ID for your two microphones.
%  Then pass it in the params struct to dual_mic_tdoa_realtime.

function list_audio_devices()
    info = audiodevinfo();
    fprintf('\n=== Available INPUT devices ===\n');
    fprintf('%-5s  %-40s  %-8s\n', 'ID', 'Name', 'Channels');
    fprintf('%s\n', repmat('-',1,58));
    for k = 1:numel(info.input)
        fprintf('%-5d  %-40s  %-8d\n', ...
            info.input(k).ID, ...
            info.input(k).Name, ...
            info.input(k).NrInputChannels);
    end
    fprintf('\nPass the desired ID as:  params.deviceID = <ID>;\n');
    fprintf('then call:              dual_mic_tdoa_realtime(params);\n\n');
end


%% =========================================================================
%% offline_test_tdoa.m
%  Test the GCC-PHAT pipeline with a synthetic stereo WAV (no hardware needed).
%  Generates a known delay, runs the filter + estimator, and reports error.
% =========================================================================
function offline_test_tdoa()

    % --- Synthetic signal parameters ------------------------------------
    fs          = 44100;
    duration    = 2.0;        % seconds
    truedelay   = 15;         % samples (known ground truth)
    bpLow       = 300;        % Hz
    bpHigh      = 3400;       % Hz
    bpOrder     = 6;
    frameSize   = 1024;
    snr_dB      = 20;         % additive noise level

    fprintf('=== Offline TDOA test ===\n');
    fprintf('True delay: %d samples = %.3f ms\n', truedelay, truedelay/fs*1000);

    % --- Generate broadband noise + delay --------------------------------
    n = round(duration * fs);
    x1_clean = randn(n, 1);

    % Fractional-sample delay via FFT
    freqs = (0:n-1)' / n;
    X1    = fft(x1_clean);
    x2_clean = real(ifft(X1 .* exp(-1j*2*pi*freqs*truedelay)));

    % Add noise
    x1 = awgn(x1_clean, snr_dB, 'measured');
    x2 = awgn(x2_clean, snr_dB, 'measured');

    % --- Design filter ---------------------------------------------------
    Wn       = [bpLow, bpHigh] / (fs/2);
    [b, a]   = butter(bpOrder, Wn, 'bandpass');
    win      = hann(frameSize);
    nFFT     = 2 * frameSize;
    maxDelay = round(0.20 / 343 * fs) + 1;

    zi1 = zeros(max(length(a),length(b))-1, 1);
    zi2 = zeros(max(length(a),length(b))-1, 1);

    % --- Process frames --------------------------------------------------
    nFrames    = floor(n / frameSize);
    estimates  = zeros(nFrames, 1);

    for k = 1:nFrames
        idx = (k-1)*frameSize + (1:frameSize);
        s1  = x1(idx) .* win;
        s2  = x2(idx) .* win;
        [s1f, zi1] = filter(b, a, s1, zi1);
        [s2f, zi2] = filter(b, a, s2, zi2);
        [estimates(k), ~, ~] = gcc_phat_local(s1f, s2f, nFFT, maxDelay);
    end

    % --- Report ----------------------------------------------------------
    med_est = median(estimates);
    err     = abs(med_est - truedelay);
    fprintf('Median estimated delay: %d samples = %.3f ms\n', med_est, med_est/fs*1000);
    fprintf('Error: %.1f samples\n\n', err);
    if err <= 1
        fprintf('PASS: Error within 1 sample.\n');
    else
        fprintf('Note: Error > 1 sample – check SNR or frame length.\n');
    end

    % --- Plot histogram of estimates ------------------------------------
    figure('Name','Offline TDOA test');
    histogram(estimates, 'BinWidth',1,'FaceColor',[0.2 0.6 0.9]);
    xline(truedelay, 'r--', 'LineWidth',2, 'Label','Ground truth');
    xlabel('Estimated delay (samples)'); ylabel('Frame count');
    title(sprintf('GCC-PHAT estimates  (SNR=%d dB)', snr_dB));
    grid on;
end

% Local copy of gcc_phat for standalone use
function [tdoa_smp, gcc, lags] = gcc_phat_local(x1, x2, nFFT, maxDelay)
    X1   = fft(x1, nFFT);
    X2   = fft(x2, nFFT);
    G    = X1 .* conj(X2);
    G    = G ./ (abs(G) + 1e-10);
    cc   = real(ifft(G, nFFT));
    cc   = fftshift(cc);
    N    = nFFT;
    lags = (-(N/2) : (N/2)-1)';
    searchMask        = abs(lags) <= maxDelay;
    cc_search         = cc;
    cc_search(~searchMask) = 0;
    [~, peakIdx] = max(cc_search);
    tdoa_smp     = lags(peakIdx);
    gcc  = cc_search;
end
