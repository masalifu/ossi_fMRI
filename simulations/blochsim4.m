function [mx,my,mz] = blochsim4(Mi, bx, by, bz, T1, T2, dt)

%	Evolve magnetization field using time-discretized Bloch equation
%	Input
%		Mi [3,dim]	initial X,Y,Z magnetization
%					Note: normalized to magnitude <= Mo=1
%		bx,by,bz [ntime,dim]	effective X,Y,Z applied magnetic field
%					(Tesla), for rotating frame (no Bo)
%		T1	[dim]		spin-lattice relaxation time (msec)
%		T2	[dim]		spin-spin relaxation time (msec)
%		dt	[ntime 1]		time interval - vector (msec)
%	Output
%		mx,my,mz [ntime,dim]  X,Y,Z magnetization as a function of time

% constants
gambar = 42.57e3;        % gamma/2pi in kHz/T
gam = gambar*2*pi;

% size checks
if ~isreal(bx) | ~isreal(by) | ~isreal(bz) 
    bx = real(bx);
    by = real(by);
    bz = real(bz);
    disp('Warning: B field must be real valued - using only the real part');
end
if (size(bx) ~= size(by)) | (size(bx) ~= size(bz))
    disp('Error: B vectors not the same length')
    mx=0; my=0; mz=0; return;
    return;
end
if (size(bx,1) ~= length(dt))
    disp('Error: dt not same length as b vectors')
    mx=0; my=0; mz=0; return;
end

if (size(Mi,2) ~= size(bx,2))
    disp('Error: Initial magnetization not right size')
    mx=0; my=0; mz=0; return;
end
if (size(Mi,2) ~= length(T1))
    disp('Error: T1 vector not right size')
    mx=0; my=0; mz=0; return;
end
if (size(Mi,2) ~= length(T2))
    disp('Error: T2 vector not right size')
    mx=0; my=0; mz=0; return;
end

% Put Beff into units rotations, T1 and T2 into losses
% rotation angle/step
dt = dt(:);
dtrep = repmat(dt,1,size(bx,2));
bx = gam*bx.*dtrep;      
by = gam*by.*dtrep;     
bz = gam*bz.*dtrep;      

nstep = size(bx,1);
%
% Initialize outputs
mx = zeros(size(bx));
my = zeros(size(bx));
mz = zeros(size(bx));
mx(1,:) = Mi(1,:);
my(1,:) = Mi(2,:);
mz(1,:) = Mi(3,:);

% stable bloch equation simulator: rotations are explicitly
% calculated and carried out on the magnetization vector 
for lp = 2:nstep
  % input vector
  Mx0 = mx(lp-1,:)';
  My0 = my(lp-1,:)';
  Mz0 = mz(lp-1,:)';
  % applied B vector
  B = [bx(lp-1,:); by(lp-1,:); bz(lp-1,:)]';  
  % initialize variables
  Bmag = sqrt(sum(B.^2,2));		% Magnitude of applied rotation
  wx = zeros(size(B,1),1);
  wy = wx; wz = wx;
  good = Bmag ~= 0;
  if any(good)
	% axis of rotation
    wx(good) = B(good,1) ./ Bmag(good);
	wy(good) = B(good,2) ./ Bmag(good);
	wz(good) = B(good,3) ./ Bmag(good);
    % sines and cosines of rotation
    ct = cos(Bmag);	
    st = -sin(Bmag);		% negative rotations for MRI
    % Rodrigues' Rotation Formula
    Mx1 = (ct+wx.*wx.*(1-ct)).*Mx0 + (wx.*wy.*(1-ct)-wz.*st).*My0 + (wy.*st+wx.*wz.*(1-ct)).*Mz0;
    My1 = (wz.*st+wx.*wy.*(1-ct)).*Mx0 + (ct+wy.*wy.*(1-ct)).*My0 + (-wx.*st+wy.*wz.*(1-ct)).*Mz0;
    Mz1 = (-wy.*st+wx.*wz.*(1-ct)).*Mx0 + (wx.*st+wy.*wz.*(1-ct)).*My0 + (ct+wz.*wz.*(1-ct)).*Mz0;
  else
    % no B fields, just copy it
    Mx1 = Mx0;
    My1 = My0;
    Mz1 = Mz0;
  end
  % Put relaxations into losses/recovery per step
  t1 = (dt(lp-1) ./ T1(:)); 
  t2 = (1 - dt(lp-1) ./ T2(:));

  % relaxation effects: "1" in Mz since Mo=1 by assumption
  mx(lp,:) = (Mx1 .* t2)';
  my(lp,:) = (My1 .* t2)';
  mz(lp,:) = (Mz1 + (1- Mz1).* t1)';

end % end loop through time