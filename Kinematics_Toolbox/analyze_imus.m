%% analyze_imus
% Reconstruct position and orientation, from angular velocity and linear acceleration.
%
% Assumes a start in a stationary position. No compensation for drift.
%
%% Syntax
% |[q, pos] = analyze_imus(R_coarse, omega, initialPosition, acc, rate)|
%
%% Input Arguments
% * omega -- 3D Angular velocity, in [rad/s]
% * accMeasured -- 3D Linear acceleration, in [m/s^2]
% * initialPosition -- Initial Position vector, in [m]
% * R_coarse -- Rotation matrix describing the initial orientation of the sensor,
%               except a mis-orienation with respect to gravity
% * rate -- Ssampling rate, in [Hz]
% 
%% Output Arguments
% * q -- Orientation, expressed as a quaternion vector
% * pos -- 3D Position in space [m]

% -------------------
%  ver:     0.2
%  date:    June-2018
%  author:  ThH

function [q, pos] = analyze_imus(R_coarse, omega, initialPosition, accMeasured, rate)

% Orientation of \vec{g} with the sensor in the "R_coarse"
g = 9.81;
g_v = [0, 0, g];
g0 = inv(R_coarse) * g_v';

% for the remaining deviation, assume the shortest rotation to there
q_fine = q_shortest_rotation(accMeasured(1,:), g0);
R_fine = quat_convert(q_fine, 'rot_mat');

% combine the two, to form a reference orientation. Note that the sequence
% is very important!
R_ref =  R_coarse * R_fine;
q_ref = rotmat_convert(R_ref, 'quat');

% Calculate orientation q by "integrating" omega -----------------
q = calc_quat(omega, q_ref, rate, 'bf');

% Acceleration, velocity, and position ----------------------------
% From q and the measured acceleration, get the \frac{d^2x}{dt^2}
accReSensor = accMeasured - rotate_vector(g_v, q_inv(q));
accReSpace = rotate_vector(accReSensor, q);

% Make the first position the reference position
q = q_mult(q, q_inv(q(1,:)));

% compensate for drift, by assuming that averaged over the recording the
% acceleration is zero
drift = mean(accReSpace);
num_data = size(accReSpace, 1);
accReSpace = accReSpace - repmat(drift, num_data,1)*0.7;

% Position and Velocity through integration, assuming 0-velocity at t=0
vel = cumtrapz(accReSpace)/rate;
pos = cumtrapz(vel)/rate + repmat(initialPosition, num_data, 1);
