"""
K+S Model Main Class
====================

Main model implementation with initialization, scheduling, and statistics.
"""

import mesa
import numpy as np
from typing import List, Dict
import pandas as pd

# Import all agent classes
from agents import Worker, Firm, Firm1
from agents_extended import Firm2, Bank, Vintage
from agents_extended import (SearchMode, SearchDiscouragement, HiringSequence,
                            HiringOrder, FiringRule, ExpectationMode)


class KSModel(mesa.Model):
    """
    K+S Agent-Based Macroeconomic Model
    
    A stock-flow consistent ABM with heterogeneous workers, capital-good firms,
    consumption-good firms, and banks.
    """
    
    def __init__(self,
                 # Country parameters
                 tr=0.2,  # Tax rate
                 flagTax=1,  # Tax mode (0=no tax, 1=on profits, 2=+dividends)
                 TregChg=0,  # Regime change time (0=no change)
                 gG=0.02,  # Government expenditure growth
                 mPer=4,  # Moving average periods
                 mLim=0.1,  # Moving average limit
                 omicron=0.5,  # Entry sensitivity
                 stick=0.1,  # Firm number stickiness
                 Crec=0.5,  # Consumption recovery limit
                 
                 # Financial parameters
                 B=10,  # Number of banks
                 Lambda=2.0,  # Credit multiple
                 tauB=0.08,  # Bank capital adequacy
                 rT=0.04,  # Target interest rate
                 muD=0.2,  # Deposit spread
                 muDeb=0.3,  # Debt spread
                 muRes=0.5,  # Reserve spread
                 alphaB=1.5,  # Bank size heterogeneity
                 betaB=0.5,  # Financial fragility sensitivity
                 dB=0.5,  # Bank dividend rate
                 EqB0=0.1,  # Initial bank equity
                 kConst=0.02,  # Credit class interest premium
                 piT=0.02,  # Target inflation
                 Ut=0.05,  # Target unemployment
                 gammaPi=0.5,  # Taylor rule inflation sensitivity
                 gammaU=0.5,  # Taylor rule unemployment sensitivity
                 flagCreditRule=2,  # Credit rule (0=none, 1=multiplier, 2=Basel)
                 
                 # Capital sector parameters
                 F10=20,  # Initial number of firm1
                 F1max=50,  # Maximum firm1
                 F1min=10,  # Minimum firm1
                 NW10=100.0,  # Initial net worth firm1
                 Deb10ratio=0.5,  # Initial debt ratio firm1
                 mu1=0.3,  # Markup firm1
                 nu=0.1,  # R&D share
                 m1=1.0,  # Worker output firm1
                 xi=0.5,  # Innovation share in R&D
                 zeta1=1.5,  # Innovation success elasticity
                 zeta2=1.5,  # Imitation success elasticity
                 alpha1=3.0,  # Innovation beta alpha
                 beta1=3.0,  # Innovation beta beta
                 alpha2=3.0,  # Imitation beta alpha
                 beta2=3.0,  # Imitation beta beta
                 x1inf=-0.05,  # Innovation lower support
                 x1sup=0.15,  # Innovation upper support
                 gamma=0.1,  # New customer share
                 d1=0.5,  # Dividend rate firm1
                 L1rdMax=0.3,  # Max R&D labor share
                 L1shortMax=0.2,  # Max labor shortage
                 
                 # Consumption sector parameters
                 F20=100,  # Initial number of firm2
                 F2max=200,  # Maximum firm2
                 F2min=50,  # Minimum firm2
                 NW20=50.0,  # Initial net worth firm2
                 Deb20ratio=0.5,  # Initial debt ratio firm2
                 mu20=0.3,  # Initial markup firm2
                 b=5,  # Payback period
                 m2=1.0,  # Machine output
                 iota=0.1,  # Inventory target
                 u=0.8,  # Planned utilization
                 eta=20,  # Machine lifetime
                 chi=1.0,  # Replicator dynamics selectivity
                 upsilon=0.05,  # Markup adjustment sensitivity
                 e0=0.5,  # Animal spirits
                 e1=1.0, e2=0.0, e3=0.0, e4=0.0,  # Expectation weights
                 e5=0.5,  # Acceleration rate
                 e6=0.3,  # Adaptive expectation factor
                 e7=0.5, e8=0.1,  # Extrapolative factors
                 d2=0.5,  # Dividend rate firm2
                 omega1=1.0,  # Price competitiveness weight
                 omega2=1.0,  # Unfilled demand competitiveness weight
                 omega3=0.5,  # Quality competitiveness weight
                 f2min=0.001,  # Minimum market share
                 flagExpect=0,  # Expectation mode
                 
                 # Labor parameters
                 Ls0=1000,  # Initial labor supply
                 Lscale=1,  # Labor scaling
                 Tr=200,  # Retirement age (0=no retirement)
                 Tc=4,  # Contract term
                 Ts=2,  # Wage memory periods
                 delta=0.01,  # Labor force growth
                 omega=3,  # Job applications (employed)
                 omegaU=5,  # Job applications (unemployed)
                 omegaPreChg=3,  # Applications pre-change
                 phi=0.5,  # Unemployment benefit rate
                 w0min=1.0,  # Minimum wage
                 psi1=0.5,  # Inflation wage sensitivity
                 psi2=0.5,  # Productivity wage sensitivity
                 psi3=-0.5,  # Unemployment wage sensitivity
                 psi6=0.1,  # Bonus share
                 sigma=0.5,  # Public skill learning
                 tauT=0.02,  # Tenure skill learning
                 tauU=0.05,  # Unemployed skill loss
                 tauG=0.01,  # Training skill gain
                 Gamma=0.3,  # Training coverage
                 theta=0.1,  # Hiring slack
                 kappa=1.0,  # Global search intensity
                 lambda_search=1.0,  # Individual search intensity
                 
                 # Control flags
                 flagSearchMode=0,  # Search mode
                 flagSearchDisc=0,  # Search discouragement
                 flagHireSeq=0,  # Hiring sequence
                 flagHireOrder1=0,  # Hiring order sector 1
                 flagHireOrder2=0,  # Hiring order sector 2
                 flagFireOrder1=0,  # Firing order sector 1
                 flagFireOrder2=0,  # Firing order sector 2
                 flagFireRule=2,  # Firing rule
                 flagWageOffer=1,  # Wage offer mode
                 flagWorkerLBU=3,  # Worker learning mode (0-3)
                 flagWorkerSkProd=3,  # Skills effect on productivity
                 
                 # Random seed
                 seed=None):
        """Initialize K+S model with parameters"""
        super().__init__(seed=seed)
        
        # Store all parameters
        self.tr = tr
        self.flagTax = flagTax
        self.TregChg = TregChg
        self.gG = gG
        self.mPer = mPer
        self.mLim = mLim
        self.omicron = omicron
        self.stick = stick
        self.Crec = Crec
        
        # Financial
        self.B = B
        self.Lambda = Lambda
        self.tauB = tauB
        self.r = rT  # Current interest rate
        self.rDeb = rT * (1 + muDeb)
        self.rD = rT * (1 - muD)
        self.rRes = rT * (1 - muRes)
        self.muDeb = muDeb
        self.muD = muD
        self.muRes = muRes
        self.alphaB = alphaB
        self.betaB = betaB
        self.dB = dB
        self.EqB0 = EqB0
        self.kConst = kConst
        self.piT = piT
        self.Ut = Ut
        self.gammaPi = gammaPi
        self.gammaU = gammaU
        self.flagCreditRule = flagCreditRule
        
        # Capital sector
        self.F10 = F10
        self.F1max = F1max
        self.F1min = F1min
        self.NW10 = NW10
        self.Deb10ratio = Deb10ratio
        self.mu1 = mu1
        self.nu = nu
        self.m1 = m1
        self.xi = xi
        self.zeta1 = zeta1
        self.zeta2 = zeta2
        self.alpha1 = alpha1
        self.beta1 = beta1
        self.alpha2 = alpha2
        self.beta2 = beta2
        self.x1inf = x1inf
        self.x1sup = x1sup
        self.gamma = gamma
        self.d1 = d1
        self.L1rdMax = L1rdMax
        self.L1shortMax = L1shortMax
        
        # Consumption sector
        self.F20 = F20
        self.F2max = F2max
        self.F2min = F2min
        self.NW20 = NW20
        self.Deb20ratio = Deb20ratio
        self.mu20 = mu20
        self.b = b
        self.m2 = m2
        self.iota = iota
        self.u = u
        self.eta = eta
        self.chi = chi
        self.upsilon = upsilon
        self.e0 = e0
        self.e1, self.e2, self.e3, self.e4 = e1, e2, e3, e4
        self.e5 = e5
        self.e6 = e6
        self.e7, self.e8 = e7, e8
        self.d2 = d2
        self.omega1 = omega1
        self.omega2 = omega2
        self.omega3 = omega3
        self.f2min = f2min
        self.f_min = f2min  # Alias for both sectors
        self.flagExpect = flagExpect
        
        # Labor
        self.Ls0 = Ls0
        self.Ls = Ls0
        self.Lscale = Lscale
        self.Tr = Tr
        self.Tc = Tc
        self.Ts = Ts
        self.delta = delta
        self.omega = omega
        self.omegaU = omegaU
        self.omegaPreChg = omegaPreChg
        self.phi = phi
        self.w0min = w0min
        self.wMinPol = w0min
        self.wU = phi * w0min  # Unemployment benefit based on MINIMUM wage
        self.wAvg = w0min
        self.psi1 = psi1
        self.psi2 = psi2
        self.psi3 = psi3
        self.psi6 = psi6
        self.sigma = sigma
        self.tauT = tauT
        self.tauU = tauU
        self.tauG = tauG
        self.Gamma = Gamma
        self.theta = theta
        self.kappa = kappa
        self.lambda_search = lambda_search
        
        # Control flags
        self.flagSearchMode = flagSearchMode
        self.flagSearchDisc = flagSearchDisc
        self.flagHireSeq = flagHireSeq
        self.flagHireOrder1 = flagHireOrder1
        self.flagHireOrder2 = flagHireOrder2
        self.flagFireOrder1 = flagFireOrder1
        self.flagFireOrder2 = flagFireOrder2
        self.flagFireRule = flagFireRule
        self.flagWageOffer = flagWageOffer
        self.flagWorkerLBU = flagWorkerLBU
        self.flagWorkerSkProd = flagWorkerSkProd
        
        # Initial values - Calculate properly based on C++ initialization
        # From fun_KS_country.h lines 477-491
        self.initial_skill = 1.0  # INISKILL
        INIPROD = 1.0  # Initial notional machine productivity
        INIWAGE = 1.0  # Initial notional wage
        
        # Calculate initial productivity for sector 1 (capital goods)
        # Btau0 = (1 + mu1) * INIPROD / (m1 * m2 * b)
        self.Btau0 = (1 + mu1) * INIPROD / (m1 * m2 * b)
        self.initial_productivity = INIPROD
        
        # Calculate initial costs and prices
        self.c10 = INIWAGE / (self.Btau0 * m1)  # initial cost sector 1
        self.c20 = INIWAGE / INIPROD  # initial cost sector 2  
        self.p10 = (1 + mu1) * self.c10  # initial price sector 1
        self.p20 = (1 + mu20) * self.c20  # initial price sector 2
        
        # Calculate initial demands based on circular flow
        trW = tr if tr > 0 else 0  # tax rate on wages
        self.K0 = Ls0 * INIWAGE / self.p20  # full employment capital required
        self.D10 = self.K0 / (m2 * eta)  # initial demand for sector 1
        self.RD0 = nu * self.D10 * self.p10  # initial R&D expense
        # Circular flow equation for initial consumption demand
        self.D20 = ((self.D10 * self.c10 + self.RD0) * (1 - phi - trW) + 
                    Ls0 * INIWAGE * phi) / (mu20 + phi + trW) * self.c20
        
        # Initial labor demands
        self.Ld10 = self.RD0 / INIWAGE + self.D10 / (self.Btau0 * m1)
        self.Ld20 = self.D20 / INIPROD
        
        # Initial aggregate productivity
        self.A0 = (self.D10 * self.p10 + self.D20 * self.p20) / (self.Ld10 + self.Ld20)
        
        # Store initial prices for real calculations
        self.pK0 = self.p10  # Initial capital goods price
        self.pC0 = self.p20  # Initial consumption goods price
        
        # Macro statistics
        self.GDPreal = 0.0
        self.GDPnom = 0.0
        self.Ue = 0.0  # Unemployment rate
        self.CPI = self.p20  # Initialize CPI at initial price level
        self.dCPI = 0.0
        self.SavAcc = 0.0  # Accumulated savings
        self.Sav = 0.0  # Current savings
        self.Tax = 0.0  # Total taxes
        self.G = self.gG * Ls0  # Initial government expenditure
        self.Def = 0.0  # Deficit
        self.Deb = 0.0  # Public debt
        
        # Investment and inventory tracking
        self.Ireal = 0.0  # Real investment
        self.Inom = 0.0  # Nominal investment
        self.dNnom = 0.0  # Nominal inventory change
        self.Creal = 0.0  # Real consumption
        self.C = 0.0  # Nominal consumption
        
        # Data collector
        self.datacollector = mesa.DataCollector(
            model_reporters={
                "GDP": lambda m: m.GDPreal,
                "Unemployment": lambda m: m.Ue,
                "Inflation": lambda m: m.dCPI,
                "Num_Firms1": lambda m: len(m.get_agents_of_type(Firm1)),
                "Num_Firms2": lambda m: len(m.get_agents_of_type(Firm2)),
                "Wages": lambda m: m.wAvg,
                "Interest_Rate": lambda m: m.r,
                "Public_Debt": lambda m: m.Deb,
            }
        )
        
        # Initialize model
        self.initialize_agents()
        
        # Running
        self.running = True
    
    def get_agents_of_type(self, agent_type):
        """Get all agents of a specific type"""
        return self.agents.select(agent_type=agent_type)
    
    def initialize_agents(self):
        """Initialize all agents"""
        # Create banks
        banks = []
        for i in range(self.B):
            bank = Bank(i, self)
            banks.append(bank)
        
        # Create firm1 (capital-good sector)
        firm1_list = []
        for i in range(self.F10):
            firm1 = Firm1(i, self)
            # Assign bank
            firm1.bank = self.random.choice(banks)
            firm1.bank.clients1.append(firm1)
            firm1_list.append(firm1)
        
        # Create firm2 (consumption-good sector)
        firm2_list = []
        for i in range(self.F20):
            firm2 = Firm2(self.F10 + i, self)
            # Assign bank
            firm2.bank = self.random.choice(banks)
            firm2.bank.clients2.append(firm2)
            # Assign supplier
            firm2.supplier = self.random.choice(firm1_list)
            firm2.supplier.clients.append(firm2)
            firm2_list.append(firm2)
        
        # Create workers
        workers = []
        for i in range(self.Ls0):
            worker = Worker(self.F10 + self.F20 + i, self)
            workers.append(worker)
        
        # Initial worker allocation following C++ initialization
        # Allocate workers to match initial labor demands Ld10 and Ld20
        # Distribute proportionally among firms
        
        # Sector 1: Ld10 total workers needed
        Ld10_per_firm = int(self.Ld10 / max(self.F10, 1))
        worker_idx = 0
        for firm1 in firm1_list:
            for _ in range(Ld10_per_firm):
                if worker_idx < len(workers):
                    worker = workers[worker_idx]
                    firm1.hire_worker(worker, self.w0min)
                    worker.employed = 1
                    worker_idx += 1
        
        # Sector 2: Ld20 total workers needed
        Ld20_per_firm = int(self.Ld20 / max(self.F20, 1))
        for firm2 in firm2_list:
            for _ in range(Ld20_per_firm):
                if worker_idx < len(workers):
                    worker = workers[worker_idx]
                    # Assign to first vintage
                    vintage = firm2.vintages[0] if len(firm2.vintages) > 0 else None
                    firm2.hire_worker(worker, self.w0min, vintage)
                    worker.employed = 2
                    worker_idx += 1
    
    def step(self):
        """Execute one time step"""
        t = self.steps
        
        # 1. Regime change check
        if t == self.TregChg:
            self.apply_regime_change()
        
        # 2. Central bank: set interest rate
        self.central_bank_policy()
        
        # 3. Firm2: form expectations and plan production
        for firm2 in self.get_agents_of_type(Firm2):
            firm2.form_expectations()
            firm2.plan_production()
            firm2.select_supplier()
        
        # 4. Firm1: R&D, receive orders, plan production
        for firm1 in self.get_agents_of_type(Firm1):
            firm1.rd_innovation_imitation()
            firm1.receive_orders()
            firm1.plan_production()
        
        # 5. Workers: update search probabilities and apply for jobs
        for worker in self.get_agents_of_type(Worker):
            worker.calculate_search_probability()
            worker.apply_for_jobs()
        
        # 6. Firms: hire/fire workers
        # Sector 1 in random order
        for firm1 in self.get_agents_of_type(Firm1):
            firm1.hire_fire_workers()
        
        # Sector 2 in specified order
        firm2_list = list(self.get_agents_of_type(Firm2))
        if self.flagHireSeq == HiringSequence.HIGHER_WAGE_FIRST:
            firm2_list.sort(key=lambda f: f.wage_offer, reverse=True)
        elif self.flagHireSeq == HiringSequence.NO_WORKERS_FIRST:
            no_workers = [f for f in firm2_list if f.L == 0]
            with_workers = [f for f in firm2_list if f.L > 0]
            self.random.shuffle(with_workers)
            firm2_list = no_workers + with_workers
        elif self.flagHireSeq == HiringSequence.NO_WORKERS_THEN_HIGHER_WAGE:
            no_workers = [f for f in firm2_list if f.L == 0]
            with_workers = [f for f in firm2_list if f.L > 0]
            with_workers.sort(key=lambda f: f.wage_offer, reverse=True)
            firm2_list = no_workers + with_workers
        
        for firm2 in firm2_list:
            firm2.hire_fire_workers()
        
        # 7. Production
        for firm1 in self.get_agents_of_type(Firm1):
            firm1.produce()
        
        for firm2 in self.get_agents_of_type(Firm2):
            firm2.produce()
        
        # 7.5. CRITICAL FIX: Deliver machines from Firm1 to Firm2
        for firm2 in self.get_agents_of_type(Firm2):
            if firm2.machine_order > 0 and firm2.supplier:
                # Deliver ordered machines (simplified - instant delivery)
                firm2.receive_machines(firm2.machine_order)
                # Firm1 records the sale
                firm2.supplier.Q1sold = getattr(firm2.supplier, 'Q1sold', 0) + firm2.machine_order
                firm2.machine_order = 0  # Reset order
        
        # 8. Price setting
        for firm1 in self.get_agents_of_type(Firm1):
            firm1.p1 = (1 + self.mu1) * self.get_sector1_avg_wage() / firm1.Btau / self.m1
        
        for firm2 in self.get_agents_of_type(Firm2):
            firm2.set_price()
        
        # 9. Government expenditure
        self.government_expenditure()
        
        # 10. Consumption demand and market matching
        self.match_consumption_market()
        
        # 11. Update competitiveness and market shares
        for firm2 in self.get_agents_of_type(Firm2):
            firm2.update_competitiveness()
        
        self.update_market_shares()
        
        # 12. Compute financial results
        for firm1 in self.get_agents_of_type(Firm1):
            firm1.compute_financials()
        
        for firm2 in self.get_agents_of_type(Firm2):
            firm2.compute_financials()
        
        # 13. Credit market
        for bank in self.get_agents_of_type(Bank):
            bank.collect_deposits()
            bank.evaluate_credit_requests()
            bank.supply_credit()
        
        # 14. Bank financials and reserve management
        for bank in self.get_agents_of_type(Bank):
            bank.compute_financials()
            bank.manage_reserves()
        
        # 15. Government finances
        self.government_finances()
        
        # 16. Bailouts
        self.bailout_banks()
        
        # 17. Entry and exit
        self.process_exits()
        self.process_entries()
        
        # 18. Worker aging and skills
        for worker in self.get_agents_of_type(Worker):
            worker.update_skills()
            worker.age_one_period()
            if worker.employed:
                worker.Te += 1
        
        # 19. Update statistics
        self.update_statistics()
        
        # 20. Data collection
        self.datacollector.collect(self)
    
    def central_bank_policy(self):
        """Central bank sets interest rate (Taylor rule)"""
        # Simplified Taylor rule
        pi_gap = self.dCPI - self.piT
        U_gap = self.Ue - self.Ut
        
        # Taylor rule: r_new = r_natural + gammaPi * pi_gap + gammaU * U_gap
        # More conservative adjustment to avoid runaway interest rates
        adjustment = self.gammaPi * pi_gap + self.gammaU * U_gap
        
        # Limit adjustment magnitude to prevent instability
        max_adjustment = 0.01  # Maximum 1 percentage point change per period
        adjustment = np.clip(adjustment, -max_adjustment, max_adjustment)
        
        r_new = self.r + adjustment
        
        # Floor and ceiling for interest rate
        r_new = np.clip(r_new, 0.001, 0.20)  # Between 0.1% and 20%
        
        self.r = r_new
        self.rDeb = self.r * (1 + self.muDeb)
        self.rD = self.r * (1 - self.muD)
        self.rRes = self.r * (1 - self.muRes)
    
    def match_consumption_market(self):
        """Match consumption demand with supply"""
        # Total consumption demand from workers following C++ Cd equation
        # Cd = W + G + Bon(-1) - TaxW + Div(-1) - TaxDiv + SavAcc adjustments
        
        # Current period wages and unemployment benefits
        W = sum(w.w for w in self.get_agents_of_type(Worker) if w.employed)
        G = self.G  # Unemployment benefits
        
        # Past period bonuses (stored from previous period)
        Bon_prev = getattr(self, 'Bon_prev', 0)
        
        # Past period dividends
        Div_prev = getattr(self, 'Div_prev', 0)
        
        # Taxes
        TaxW = getattr(self, 'TaxW', 0)
        TaxDiv = getattr(self, 'TaxDiv', 0)
        
        # Base consumption demand
        Cd = W + G + Bon_prev - TaxW + Div_prev - TaxDiv
        
        # Handle accumulated forced savings (flagCons=2: slow spend)
        # Recover up to a limit of current consumption
        if self.SavAcc > 0:
            max_recover = Cd * self.Crec  # max recover limit
            if self.SavAcc <= max_recover:
                Cd += self.SavAcc
                self.SavAcc = 0
            else:
                Cd += max_recover
                self.SavAcc -= max_recover
        
        # Store Cd for statistics
        self.Cd = Cd
        
        # Allocate demand by market shares
        D2_total = 0
        for firm2 in self.get_agents_of_type(Firm2):
            firm2.D2d = firm2.f * Cd
            firm2.D2 = min(firm2.D2d, firm2.Q2e + firm2.N)
            firm2.unfilled_demand = firm2.D2d - firm2.D2
            D2_total += firm2.D2
        
        # Forced savings
        self.Sav = max(Cd - D2_total, 0)
        self.SavAcc += self.Sav
        
        # Store values for next period
        Bon_current = sum(getattr(f, 'Bon2', 0) for f in self.get_agents_of_type(Firm2))
        self.Bon_prev = Bon_current
        Div_current = sum(f.Div for f in self.get_agents_of_type(Firm1))
        Div_current += sum(f.Div for f in self.get_agents_of_type(Firm2))
        from agents_extended import Bank
        Div_current += sum(b.DivB for b in self.get_agents_of_type(Bank))
        self.Div_prev = Div_current
    
    def update_market_shares(self):
        """Update market shares using replicator dynamics"""
        # Firm2 market shares
        firm2_agents = list(self.get_agents_of_type(Firm2))
        if len(firm2_agents) > 0:
            # Calculate weighted competitiveness
            # Add safety check to prevent division by zero
            E_weighted = sum(f2.f * f2.E for f2 in firm2_agents)
            
            for firm2 in firm2_agents:
                # Replicator dynamics with bounded change
                f2_new = firm2.f * (1 + self.chi * (firm2.E - E_weighted))
                # Ensure non-negative and bounded
                firm2.f = max(f2_new, self.f_min)
            
            # Normalize to sum to 1
            f2_total = sum(f2.f for f2 in firm2_agents)
            if f2_total > 0:
                for firm2 in firm2_agents:
                    firm2.f = firm2.f / f2_total
            else:
                # Fallback: equal shares
                for firm2 in firm2_agents:
                    firm2.f = 1.0 / len(firm2_agents)
        
        # Firm1 market shares (based on clients)
        firm1_agents = list(self.get_agents_of_type(Firm1))
        if len(firm1_agents) > 0:
            # Total clients across all firm1
            total_clients = sum(len(f1.clients) for f1 in firm1_agents)
            for firm1 in firm1_agents:
                firm1.f = len(firm1.clients) / max(total_clients, 1) if total_clients > 0 else 1.0 / len(firm1_agents)
    
    def government_expenditure(self):
        """Calculate government expenditure"""
        # G = unemployment benefits + training (simplified)
        # Following C++ equation with flagGovExp < 2 (work-or-die or minimum)
        unemployed_count = len([w for w in self.get_agents_of_type(Worker) if not w.employed])
        
        # Use unemployment benefit rate times minimum wage (not average wage)
        # This prevents positive feedback loop
        unemployment_benefits = unemployed_count * self.wU
        
        # Training costs (simplified, proportional to unemployed)
        if hasattr(self, 'Gamma') and hasattr(self, 'tauG'):
            training_cost = self.Gamma * unemployed_count * self.w0min * 0.1  # Small fraction
        else:
            training_cost = 0
        
        self.G = unemployment_benefits + training_cost
    
    def government_finances(self):
        """Calculate government finances"""
        # Collect taxes on wages
        employed_workers = [w for w in self.get_agents_of_type(Worker) if w.employed]
        self.TaxW = sum(w.w * self.tr for w in employed_workers) if self.tr > 0 else 0
        
        # Collect taxes on firm profits
        self.Tax = self.TaxW
        self.Tax += sum(f.Tax for f in self.get_agents_of_type(Firm1))
        self.Tax += sum(f.Tax for f in self.get_agents_of_type(Firm2))
        from agents_extended import Bank
        self.Tax += sum(b.TaxB for b in self.get_agents_of_type(Bank))
        
        # Taxes on dividends if flagTax >= 2
        if hasattr(self, 'flagTax') and self.flagTax >= 2:
            Div_current = self.Div_prev if hasattr(self, 'Div_prev') else 0
            self.TaxDiv = Div_current * self.tr
            self.Tax += self.TaxDiv
        else:
            self.TaxDiv = 0
        
        # Primary deficit (positive means spending > taxes)
        DefP = self.G - self.Tax
        
        # Total deficit (including interest payments, simplified for now)
        self.Def = DefP
        
        # Debt accumulation (debt increases with deficits)
        self.Deb = max(self.Deb + self.Def, 0)  # Debt cannot be negative
    
    def bailout_banks(self):
        """Bailout banks with negative net worth"""
        for bank in self.get_agents_of_type(Bank):
            if bank.bailout_condition():
                # Simplified bailout
                bailout = -bank.NWb + self.EqB0 * self.NW10
                bank.NWb = self.EqB0 * self.NW10
                self.G += bailout
    
    def process_exits(self):
        """Remove firms that meet exit conditions"""
        from agents_extended import Firm2
        
        # Firm1 exits
        exiting_firm1 = [f for f in self.get_agents_of_type(Firm1) if f.exit_condition()]
        for firm1 in exiting_firm1:
            # Fire workers
            for worker in firm1.workers[:]:
                firm1.fire_worker(worker)
            
            # Bad debt
            if firm1.bank and firm1.Deb > 0:
                firm1.bank.add_bad_debt(firm1.Deb)
            
            # Remove from clients
            for firm2 in self.get_agents_of_type(Firm2):
                if firm2.supplier == firm1:
                    # Reassign to random supplier
                    other_firm1 = [f for f in self.get_agents_of_type(Firm1) if f != firm1]
                    if len(other_firm1) > 0:
                        firm2.supplier = self.random.choice(other_firm1)
                        firm2.supplier.clients.append(firm2)
                    else:
                        firm2.supplier = None
            
            firm1.remove()
        
        # Firm2 exits
        exiting_firm2 = [f for f in self.get_agents_of_type(Firm2) if f.exit_condition()]
        for firm2 in exiting_firm2:
            # Fire workers
            for worker in firm2.workers[:]:
                firm2.fire_worker(worker)
            
            # Bad debt
            if firm2.bank and firm2.Deb > 0:
                firm2.bank.add_bad_debt(firm2.Deb)
            
            # Remove from supplier clients
            if firm2.supplier and firm2 in firm2.supplier.clients:
                firm2.supplier.clients.remove(firm2)
            
            firm2.remove()
    
    def process_entries(self):
        """Add new entrant firms based on profitability and target numbers"""
        from agents_extended import Firm2, Bank
        
        # Entry logic for Firm1 - more conservative
        firm1_count = len(self.get_agents_of_type(Firm1))
        if firm1_count < self.F1min:
            # Below minimum, need entries (but limit to avoid huge jumps)
            num_entries1 = min(self.F1min - firm1_count, 5)
        elif firm1_count > self.F1max:
            # Above maximum, no entries
            num_entries1 = 0
        else:
            # Check profitability for entry - more conservative
            firm1_agents = list(self.get_agents_of_type(Firm1))
            if len(firm1_agents) > 0:
                avg_profit1 = np.mean([f.Pi for f in firm1_agents])
                avg_NW1 = np.mean([f.NW for f in firm1_agents])
                # Only allow entry if profitable AND above half target
                if avg_profit1 > 0 and avg_NW1 > 0 and firm1_count > self.F10 * 0.5:
                    # More conservative entry rate
                    num_entries1 = max(0, min(int(self.omicron * 0.5 * (self.F10 - firm1_count)), 2))
                else:
                    num_entries1 = 0
            else:
                # No firms - need at least one
                num_entries1 = 1
        
        # Entry logic for Firm2 - more conservative
        firm2_count = len(self.get_agents_of_type(Firm2))
        if firm2_count < self.F2min:
            # Below minimum, need entries (but limit to avoid huge jumps)
            num_entries2 = min(self.F2min - firm2_count, 10)
        elif firm2_count > self.F2max:
            # Above maximum, no entries
            num_entries2 = 0
        else:
            # Check profitability for entry - more conservative
            firm2_agents = list(self.get_agents_of_type(Firm2))
            if len(firm2_agents) > 0:
                avg_profit2 = np.mean([f.Pi for f in firm2_agents])
                avg_NW2 = np.mean([f.NW for f in firm2_agents])
                # Only allow entry if profitable AND above half target
                if avg_profit2 > 0 and avg_NW2 > 0 and firm2_count > self.F20 * 0.5:
                    # More conservative entry rate
                    num_entries2 = max(0, min(int(self.omicron * 0.5 * (self.F20 - firm2_count)), 5))
                else:
                    num_entries2 = 0
            else:
                # No firms - need at least one
                num_entries2 = 1
        
        # Create entrant Firm1
        banks = list(self.get_agents_of_type(Bank))
        # Get max existing ID to avoid conflicts
        max_id = max([a.unique_id for a in self.agents], default=0)
        
        for i in range(num_entries1):
            max_id += 1
            firm1 = Firm1(max_id, self)
            # Assign bank
            firm1.bank = self.random.choice(banks) if len(banks) > 0 else None
            if firm1.bank:
                firm1.bank.clients1.append(firm1)
        
        # Create entrant Firm2
        firm1_list = list(self.get_agents_of_type(Firm1))
        for i in range(num_entries2):
            max_id += 1
            firm2 = Firm2(max_id, self)
            # Initialize with expected demand based on capacity
            firm2.D2e = self.u * firm2.K * self.m2
            firm2.D2d = firm2.D2e
            # Assign bank
            firm2.bank = self.random.choice(banks) if len(banks) > 0 else None
            if firm2.bank:
                firm2.bank.clients2.append(firm2)
            # Assign supplier
            if len(firm1_list) > 0:
                firm2.supplier = self.random.choice(firm1_list)
                firm2.supplier.clients.append(firm2)
    
    def apply_regime_change(self):
        """Apply regime change at specified time"""
        # Would update parameters for post-change regime
        pass
    
    def update_statistics(self):
        """Update macro statistics"""
        # Employment
        employed = len([w for w in self.get_agents_of_type(Worker) if w.employed])
        self.Ls = len(self.get_agents_of_type(Worker))
        self.Ue = (self.Ls - employed) / max(self.Ls, 1)
        
        # Wages
        employed_workers = [w for w in self.get_agents_of_type(Worker) if w.employed]
        if len(employed_workers) > 0:
            self.wAvg = np.mean([w.w for w in employed_workers])
            # wU should stay based on minimum wage to prevent feedback loop
            # self.wU = self.phi * self.wAvg  # DON'T update wU dynamically
        
        # Consumption (nominal and real)
        # C = total sales of consumption goods
        self.C = sum(f.S for f in self.get_agents_of_type(Firm2))
        # Creal = consumption in initial prices
        Q2_total = sum(f.Q2e for f in self.get_agents_of_type(Firm2))
        self.Creal = Q2_total * self.pC0
        
        # Investment (nominal and real)
        # Inom = total sales of capital goods
        self.Inom = sum(f.S for f in self.get_agents_of_type(Firm1))
        # Ireal = investment in initial prices
        Q1_total = sum(f.Q1e for f in self.get_agents_of_type(Firm1))
        self.Ireal = Q1_total * self.pK0
        
        # Inventory change (nominal)
        N_current = sum(f.N for f in self.get_agents_of_type(Firm2))
        if not hasattr(self, 'N_previous'):
            self.N_previous = 0
        self.dNnom = N_current - self.N_previous
        self.N_previous = N_current
        
        # GDP calculation following C++ implementation
        # GDPreal = max(Ireal + Creal, 1)
        # GDPnom = max(C + Inom + dNnom, 1)
        self.GDPreal = max(self.Ireal + self.Creal, 1)
        self.GDPnom = max(self.C + self.Inom + self.dNnom, 1)
        
        # Prices and inflation
        CPI_new = self.get_avg_price_sector2()
        if self.CPI > 0:
            self.dCPI = (CPI_new - self.CPI) / self.CPI
        else:
            self.dCPI = 0
        self.CPI = CPI_new if CPI_new > 0 else self.pC0
    
    # Helper methods
    def get_unemployment_rate(self) -> float:
        return self.Ue
    
    def get_sector1_avg_wage(self) -> float:
        workers1 = [w for f in self.get_agents_of_type(Firm1) for w in f.workers]
        return np.mean([w.w for w in workers1]) if len(workers1) > 0 else self.w0min
    
    def get_sector2_avg_wage(self) -> float:
        workers2 = [w for f in self.get_agents_of_type(Firm2) for w in f.workers]
        return np.mean([w.w for w in workers2]) if len(workers2) > 0 else self.w0min
    
    def get_avg_price_sector1(self) -> float:
        firm1_agents = list(self.get_agents_of_type(Firm1))
        if len(firm1_agents) > 0:
            return np.mean([f.p1 for f in firm1_agents])
        return 1.0
    
    def get_avg_price_sector2(self) -> float:
        firm2_agents = list(self.get_agents_of_type(Firm2))
        if len(firm2_agents) > 0:
            return np.mean([f.p2 for f in firm2_agents])
        return 1.0
    
    def get_avg_unit_cost_sector2(self) -> float:
        firm2_agents = list(self.get_agents_of_type(Firm2))
        if len(firm2_agents) > 0:
            return np.mean([f.c2 for f in firm2_agents if f.c2 > 0])
        return 1.0
    
    def get_avg_profit_sector2(self) -> float:
        firm2_agents = list(self.get_agents_of_type(Firm2))
        if len(firm2_agents) > 0:
            return np.mean([f.Pi for f in firm2_agents])
        return 0.0
