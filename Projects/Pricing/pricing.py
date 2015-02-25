# -*- coding: utf-8 -*-
"""
Created on Fri Jan 23 14:26:11 2015

@author: Sean Violante
"""

import numpy as np
import pandas as pnd
from __future__ import division # real division between integers!
# global settings

# PD scale
C5_end=5 # % 
D5_end=9 # %
# round to 1 bp
# 25 risk classes and 5 between c5 and d5
cls1=['A','B','C','D','E']
cls = [c for c in cls1 for i in range(5) ] # AAAAABBBBB ...

sub=map(str,range(1,6))*5 # strings 1-5
ind=[ "".join(a) for a in zip(cls,sub)]
PD=pnd.DataFrame(0,index=ind, columns=['start','end','mid'])
PD.end = np.round(900 * np.power((D5_end / C5_end) , (np.arange(-19,6).T / 5))) / 10000.0;
PD.start = (np.round(900 * np.power((9 / 5) , (np.arange(-20,5).T / 5))) + 1) / 10000.0;
PD.mid = np.power((PD.start + 0.00005) * (PD.end + 0.00005) , 0.5);
PD.mid['A1'] = (PD.end['A1'] + 0.00005) * 0.5;



# recoveries
recovery1 = 0.5814;
rr_treshold1 = 5000;
recovery2 = 0.2613;
rr_treshold2 = 25000;
recovery3 = 0.1425;

# durations
durations = np.array([6, 12, 24, 36, 48, 60, 72, 84]);

# amounts
amounts = np.arange(rr_treshold1,50000+100,100);

# base rates
# November 2014 data from http://www.bundesbank.de/Redaktion/DE/Downloads/Statistiken/Geld_Und_Kapitalmaerkte/Zinssaetze_Renditen/S11BATRAT.pdf?__blob=publicationFile
consumer_loan_ir = 0.01 * np.array([5.02, 4.71, 4.71, 4.71, 4.71, 4.71, 7.23, 7.23]);
# 2015-01-08 data from http://www.investing.com/rates-bonds/germany-government-bonds?maturity_from=70&maturity_to=180
deposit_rates = 0.01 *np.array( [-0.086, -0.109, -0.106, -0.103, -0.068, 0.008, 0.073, 0.161]);
curve = (0.1 * consumer_loan_ir) + (0.9 * deposit_rates);
duration_adjustment = 0.01 / (1 + np.exp(-12 * 0.01 * durations) * (0.01 / 0.0005 -1));
# V1 
# volatility_adjustment = 0.01 * [0.00:0.4:1.60, 1.85:0.25:2.85, 3.00:0.15:3.60, 3.60, 3.60, 3.60, 3.60, 3.60, 3.60, 3.60, 3.60, 3.60, 3.60]';
# V2 
volatility_adjustment = 0.01 * \
    np.concatenate((np.arange(0.15,0.15+0.75,.15), 
                   np.arange(0.95,0.20+1.75,0.20), 
                    [2.00, 2.25, 2.50, 2.75],
                     np.arange(3.60,0.01+3.70,0.01))).T;
base_rates = curve + duration_adjustment + volatility_adjustment;

# service fee
service_fee = 0.01;
    
# borrower_fees
# borrower_fees = 0.01 * ([0.25, 0.50, 0.75, 1.25, 1.50, 2.25, 3.00, 3.75] .+ [0,0,0,0,0,0,0,0,0,0,0.25,0.25,0.25,0.25,0.25,0.5,0.5,0.5,0.5,0.5,0.75,0.75,0.75,0.75,0.75]');
borrower_fees = 0.0001 * np.round(10000 * 
    (
    (0.005 / (1 + np.exp(-50 * 0.005 * (np.arange(1,len(PD)+1)[np.newaxis,])) * (0.005 / 0.0001 -1))).T \
    + (0.0385 / (1 + np.exp(-1.4 * 0.0385 * durations[np.newaxis,]) * (0.0385 / 0.0025 - 1)))));

# initialize
results = np.empty((len(durations) * len(PD) * len(amounts), 9));
index = 0;

# start iterating
# iterating over durations
for i,d in enumerate(i_durations):
  print(sys.time, "yyyy-mm-dd HH-MM-SS")
  
  payments = np.zeros((1, d + 1));

  
  survival_rate = np.power(1 - PD.mid.values[:,np.newaxis],(np.arange(d,0,-1)[np.newaxis,] / 12.0))

  default_rate = np.power(1 - PD.mid.values[:,np.newaxis] , 
                          (np.arange((d - 1),-1,-1) / 12.0))  \
                          * (1 - np.power(1 - PD.mid.values[:,np.newaxis],  (1 / 12.0)));
  
  # iterating over PDs
  for i_PD,pd_mid = enumerate(PD.mid)
    base_rate = base_rates[i_PD, i];
    df = power(1 + base_rate,-1 / 12);
    
    borrower_fee = borrower_fees[i_PD, i_duration];
    
    # check base rate against min nominal rate 0.01#
    i_left = 1;      # 0.0001;
    q = 1 + i_left / 120000.0;
    installment = q ** d * i_left / 120000.0 / (q ** d - 1);
    remaining_principal = (q ** d - q .^ np.arange((d-1),-1,-1)) / (q ** d - 1);
    payments(1:d) = (
      (survival_rate[i_PD, :] .* installment) .+ 
      (default_rate[i_PD, :] .* remaining_principal .* recovery1)
    );
    if ((1 - service_fee) * polyval(payments, df) >= 1)
      disp("base rate too low - 0.01# nominal rate would be sufficient already")    
    else

      #iterating over amounts
      for amount = 1 : length(amounts)

        # search the appropriate nominal rate by calculating the present value (relative to loan amount) of the expected cash flow

        # initalize boundaries of bisection algorithm, calculating with integers for numerical stability
        index++;
        i_left = 1;      # 0.0001;

        # check the previous amount
        use_previous = false;
        if (amount > 1)
          i_right = results(index - 1, 7) * 10000;
          q = 1 + i_right / 120000.0;
          installment = q ^ d * i_right / 120000.0 / (q ^ d - 1);
          remaining_principal = (q ^ d - q .^ ((d-1):-1:0)) / (q ^ d - 1);
          payments(1:d) = (
            (survival_rate(i_PD, :) .* installment) .+ 
            (default_rate(i_PD, :) .* remaining_principal .* (
              (recovery1 - recovery2) * (remaining_principal * amounts(amount) <= rr_treshold1) .+ 
              (recovery2 - recovery3) * (remaining_principal * amounts(amount) <= rr_treshold2) .+ 
              recovery3
            ))
          );
          if ((1 - service_fee) * polyval(payments, df) >= 1)
            use_previous = true;
          else
            i_left = i_right;
          endif
        endif
        
        if (use_previous)
          results(index, :) = results(index - 1, :);
          results(index, 3) = amounts(amount);
        else
          results(index, 1:6) = [d, i_PD, amounts(amount), base_rate, service_fee, borrower_fee];
          i_right = 1700;  # 0.1700;
          q = 1 + i_right / 120000.0;
          installment = q ^ d * i_right / 120000.0 / (q ^ d - 1);
          remaining_principal = (q ^ d - q .^ ((d-1):-1:0)) / (q ^ d - 1);
          payments(1:d) = (
            (survival_rate(i_PD, :) .* installment) .+ 
            (default_rate(i_PD, :) .* remaining_principal .* (
              (recovery1 - recovery2) * (remaining_principal * amounts(amount) <= rr_treshold1) .+ 
              (recovery2 - recovery3) * (remaining_principal * amounts(amount) <= rr_treshold2) .+ 
              recovery3
            ))
          );
          if ((1 - service_fee) * polyval(payments, df) < 1)
            break; # base rate, risk costs and service fee require nominal interest rate above 17# - stop
          endif

          #bisection algorithm
          while (i_left + 1 < i_right)
            ir = floor(0.5 * (i_left + i_right));
            q = 1 + ir / 120000.0;
            installment = q ^ d * ir / 120000.0 / (q ^ d - 1);
            remaining_principal = (q ^ d - q .^ ((d-1):-1:0)) / (q ^ d - 1);
            payments(1:d) = (
              (survival_rate(i_PD, :) .* installment) .+ 
              (default_rate(i_PD, :) .* remaining_principal .* (
                (recovery1 - recovery2) * (remaining_principal * amounts(amount) <= rr_treshold1) .+ 
                (recovery2 - recovery3) * (remaining_principal * amounts(amount) <= rr_treshold2) .+ 
                recovery3
              ))
            );
            if ((1 - service_fee) * polyval(payments, df) < 1)
              i_left = ir;
            else 
              i_right = ir;
            endif
          endwhile
          
          results(index, 7) = i_right / 10000.0;
          
          # search the targeted yield and expected yield at 50# discount on service fee

          # calculate expected payments at derived nominal rate
          q = 1 + i_right / 120000.0;
          installment = q ^ d * i_right / 120000.0 / (q ^ d - 1);
          remaining_principal = (q ^ d - q .^ ((d-1):-1:0)) / (q ^ d - 1);
          payments(1:d) = (
            (survival_rate(i_PD, :) .* installment) .+ 
            (default_rate(i_PD, :) .* remaining_principal .* (
              (recovery1 - recovery2) * (remaining_principal * amounts(amount) <= rr_treshold1) .+ 
              (recovery2 - recovery3) * (remaining_principal * amounts(amount) <= rr_treshold2) .+ 
              recovery3
            ))
          );
          
          # targeted yield
          # initalize boundaries of bisection algorithm
          ty_left = base_rate;
          ty_right = i_right / 10000.0;
          
          #bisection algorithm
          while (round(ty_left * 10000) != round(ty_right * 10000))
            df_check = (1 + 0.5 * (ty_left + ty_right)) ^ (-1 / 12);
            if (polyval(payments, df_check) > 1)
              ty_left = 0.5 * (ty_left + ty_right);
            else 
              ty_right = 0.5 * (ty_left + ty_right);
            endif
          endwhile          

          results(index, 8) = round(ty_left * 10000) / 10000.0;

          # expected yield at 50# discount on service fee
          # initalize boundaries of bisection algorithm
          ty_left = base_rate;
          ty_right = i_right / 10000.0;
          
          #bisection algorithm
          while (round(ty_left * 10000) != round(ty_right * 10000))
            df_check = (1 + 0.5 * (ty_left + ty_right)) ^ (-1 / 12);
            if ((1 - 0.5 * service_fee) * polyval(payments, df_check) > 1)
              ty_left = 0.5 * (ty_left + ty_right);
            else 
              ty_right = 0.5 * (ty_left + ty_right);
            endif
          endwhile          

          results(index, 9) = round(ty_left * 10000) / 10000.0;

        endif # use_previous
  
      endfor # amounts
      
    endif # base rate check

  endfor # i_PD
    
endfor # durations

disp(datestr(now, "yyyy-mm-dd HH-MM-SS"))

# output
dlmwrite(["pricing_" datestr(now, "yyyy-mm-dd HH-MM-SS") ".csv"], results(not(isna(results(:,7))),:), ";", "precision", 5);
