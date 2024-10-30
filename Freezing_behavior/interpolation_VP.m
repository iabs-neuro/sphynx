function x = interpolation_VP (A2,bad_pos) 
x = A2;
%доработать чтобы работало для одного плохого кадра
%x0 = [0,2,3,4,0,0,0,0];
%bad_pos = [1,5,6,7,8];
%x=x0;
x_len = length(x); 
N_bad = length(bad_pos); 
if N_bad>=2
stack = 1; 
N1_stack = 1; 
i =1;
if bad_pos(1) == 1    
    for i = 2:N_bad      
        if bad_pos(i-1)+1 ~= bad_pos(i) 
            x2 = bad_pos(N1_stack)+stack;
            for l=1:stack                
                x(l) = x(x2);
            end 
            break;
            stack = 1;
            N1_stack = i;            
        else
            stack = stack+1;
        end 
    end
    if (i == N_bad)        
       x2 = bad_pos(N1_stack)+stack;         
       for l=1:stack
           x(l) = x(x2);
       end
    end
end        

stack = 1; 
N1 = i+1; 
N1_stack = i;
if N_bad>=N1
    for k = N1:N_bad      
        if bad_pos(k-1)+1 ~= bad_pos(k) 
           x1 = bad_pos(N1_stack)-1; 
           x2 = bad_pos(N1_stack)+stack;      
           for l=1:stack    
                im_bad = x(x1)*(1-l/(stack+1)) + x(x2)*l/(stack+1); 
                x(x1+l) = im_bad;
           end        
           stack = 1;
           N1_stack = k;
        else
            stack = stack+1;
        end       
    end
        if (k == N_bad) && (bad_pos(k) ~= x_len)
           x1 = bad_pos(N1_stack)-1; 
           x2 = bad_pos(N1_stack)+stack;         
           for l=1:stack
               im_bad = x(x1)*(1-l/(stack+1)) + x(x2)*l/(stack+1);
               x(x1+l) = im_bad;
           end
        else
            x1 = bad_pos(N1_stack)-1;
            for l=1:stack           
               x(x1+l) = x(x1);
            end
        end
end 
end
end 