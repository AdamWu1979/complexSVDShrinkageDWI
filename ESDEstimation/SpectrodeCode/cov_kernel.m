function K = cov_kernel(x,y,t,w_null,gamma)
%compute the numerical values of the covariance kernel K controlling the
%variance of a LSS, in a general MP model

%Inputs
%x,y -real grids
%t - eigenvalues
%w - weights
%gamma - aspect ratio

%Outputs
%K - a matrix of dimension length(x) x length(y), where 
%K(i,j) = k(x(i),x(j))
%and k(x,y) = 1/(2*pi^2)*log(1 + 4.*imag(v(x)).*imag(v(y))./abs(v(x)-v(y)).^2);
%v(x) is the companion ST of the MP forward map
%F(H,gamma)
%H = \sum_i t_i*delta(w_i)

epsilon = 1e-8;
[grid, ~, ~, v_grid] = compute_esd_ode(t, w_null, gamma,epsilon);

v_x = interpolate(x,grid,v_grid);
v_y = interpolate(y,grid,v_grid);

K_f = @(i,j) 1/(2*pi^2)*log(1 + 4*imag(v_x(i))*imag(v_y(j))/abs(v_x(i)-v_y(j))^2);

K = zeros(length(x),length(y));
multi = 1.5;
for i = 1:length(x)
    for j = 1:length(y)
        if v_x(i)==v_x(j)
            if j>1
                K(i,j) = multi *K_f(i,j-1);
            else if i>1
                    K(i,j) = multi *K_f(i-1,j);
                end
            end
        else
            K(i,j) = K_f(i,j);
        end
    end
end