function var = variance_signal(A_f_target,X_s, FFTLength, len_X_measurements)
    % Compute the variances of the signal for all frequencies at all
    % time-instances.
    var = zeros(FFTLength,len_X_measurements);
    for k = 1:FFTLength 
        A_f = A_f_target(:,k);
        normal_factor = A_f_target(:,k)*A_f_target(:,k)';
        for l = 1:len_X_measurements
            % Compute autocorrelation of the signal vector over all the M
            % antennas
            r_s = X_s(:,k,l)*X_s(:,k,l)';

            % Compute the variance by normalizing the correlation matrix
            variance = r_s./normal_factor;
            var(k,l) = real(variance(1,1));
        end
        disp(['Progress: ', num2str(FFTLength), ' from ', num2str(k)])
    end
end

