"""
K+S Model Agents (Continued): Firm2, Bank
==========================================

Continuation of agent implementations for the K+S model.
"""

from agents import *


# ============================================================================
# Firm2 Agent (Consumption-Good Sector)
# ============================================================================

class Firm2(Firm):
    """
    Consumption-good producer firm
    
    Produces consumer goods using machines and labor, sets prices with
    adaptive markup, competes based on price and quality.
    """
    
    def __init__(self, unique_id: int, model: 'KSModel'):
        super().__init__(unique_id, model)
        
        # Production
        self.Q2 = 0  # Planned production
        self.Q2e = 0  # Effective production
        self.D2 = 0  # Actual demand fulfilled
        self.D2d = 0  # Desired demand
        self.D2e = 0  # Expected demand
        self.p2 = 0.0  # Product price
        self.mu2 = model.mu20  # Mark-up
        self.c2 = 0.0  # Unit cost
        self.A2 = model.initial_productivity  # Average productivity
        
        # Capital
        self.K = 0  # Number of machines
        self.Kd = 0  # Desired capital
        self.vintages: List[Vintage] = []
        self.machine_order = 0  # Order to supplier
        
        # Market
        self.E = 0.0  # Competitiveness
        self.unfilled_demand = 0.0
        self.quality = 1.0
        
        # Inventories
        self.N = 0.0  # Inventories
        
        # Supplier
        self.supplier: Optional[Firm1] = None
        self.brochures: List[Dict] = []
        
        # Workers
        self.employed_status = 2  # Sector 2
        
        # Bonuses
        self.Bon2 = 0.0
        
        # Initialize
        self.initialize_firm2()
    
    def initialize_firm2(self):
        """Initialize firm2 specific attributes"""
        self.NW = self.model.NW20
        debt_ratio = self.model.Deb20ratio
        self.Deb = self.NW * debt_ratio / (1 - debt_ratio) if debt_ratio < 1 else 0
        self.f = 1.0 / max(self.model.F20, 1)
        
        # Initialize with capital based on K0 and firm count
        # Each firm gets approximately equal share of initial capital
        self.K = int(self.model.K0 / self.model.F20)
        initial_vintage = Vintage(
            IDvint=10000,
            t0=0,
            supplier_id=0,
            A=self.model.initial_productivity,
            machines=self.K
        )
        self.vintages.append(initial_vintage)
        
        # Use correct initial price
        self.c2 = self.model.c20
        self.p2 = self.model.p20
        
        # CRITICAL FIX: Initialize expected demand based on capacity
        # Following C++ code: _D2e = u * _K
        self.D2e = self.model.u * self.K * self.model.m2
        self.D2d = self.D2e  # Also set desired demand
        self.D2 = 0  # Actual demand fulfilled starts at 0
    
    def receive_brochure(self, supplier: Firm1):
        """Receive machine brochure from supplier"""
        brochure = {
            'firm': supplier,
            'A': supplier.Atau,
            'p': supplier.p1
        }
        self.brochures.append(brochure)
    
    def select_supplier(self):
        """Select best supplier based on payback period"""
        if len(self.brochures) == 0:
            # Keep current supplier or select random
            # Import here to avoid circular import
            from agents import Firm1
            firm1_agents = list(self.model.get_agents_of_type(Firm1))
            if self.supplier is None and len(firm1_agents) > 0:
                self.supplier = self.random.choice(firm1_agents)
            return
        
        w2avg = self.model.get_sector2_avg_wage()
        
        best_supplier = self.supplier
        best_payback = np.inf
        
        for brochure in self.brochures:
            A = brochure['A']
            p = brochure['p']
            
            if A > 0 and w2avg > 0:
                # Calculate payback period
                savings = p * A / w2avg - self.c2
                if savings > 0:
                    payback = (p / self.model.m2) / savings
                    if payback < best_payback:
                        best_payback = payback
                        best_supplier = brochure['firm']
        
        if best_supplier is not None:
            self.supplier = best_supplier
            if self not in self.supplier.clients:
                self.supplier.clients.append(self)
        
        self.brochures = []
    
    def form_expectations(self):
        """Form demand expectations"""
        if self.life_cycle < 3:
            # Entrant: optimistic expectations based on actual or desired demand
            self.D2e = max(self.D2d, self.D2e, self.D2) if self.D2e > 0 else max(self.D2d, self.D2, 1)
            return
        
        e0 = self.model.e0
        mode = ExpectationMode(self.model.flagExpect)
        
        if mode == ExpectationMode.MYOPIC_1_PERIOD:
            # Simple myopic - mix of fulfilled and desired demand
            D_mixed = (1 - e0) * self.D2 + e0 * self.D2d
            self.D2e = max(D_mixed, self.D2, 1)  # Never go below fulfilled demand
        
        elif mode == ExpectationMode.MYOPIC_4_PERIOD:
            # 4-period weighted average (simplified)
            self.D2e = max(self.D2, 1)  # Simplified - at least maintain current
        
        elif mode == ExpectationMode.ACCELERATING:
            # Accelerating expectations with bounds
            if self.D2 > 0:
                growth = (self.D2 - self.D2e) / max(self.D2, 0.01)
                # Limit growth rate to prevent explosions
                growth = np.clip(growth, -0.5, 0.5)
                self.D2e = self.D2 * (1 + self.model.e5 * growth)
            else:
                self.D2e = max(self.D2, 1)
        
        elif mode == ExpectationMode.ADAPTIVE:
            # Adaptive expectations
            self.D2e = self.D2e + self.model.e6 * (self.D2 - self.D2e)
        
        elif mode == ExpectationMode.EXTRAPOLATIVE_ACCELERATING:
            # Extrapolative with bounds
            if self.D2 > 0:
                growth = (self.D2 - self.D2e) / max(self.D2, 0.01)
                # Limit growth rate to prevent explosions
                growth = np.clip(growth, -0.5, 0.5)
                self.D2e = self.D2 * (1 + self.model.e7 * growth + self.model.e8 * growth**2)
            else:
                self.D2e = max(self.D2, 1)
        
        # Ensure expectations are positive and bounded
        self.D2e = max(self.D2e, 1)
        # Limit extreme expectations to prevent crashes
        if self.D2 > 0:
            self.D2e = np.clip(self.D2e, self.D2 * 0.1, self.D2 * 10)
    
    def plan_production(self):
        """Plan production and investment"""
        # Desired production with inventory target
        self.Q2 = max(self.D2e + self.model.iota * self.D2e - self.N, 0)
        
        # Calculate average productivity
        self.A2 = self.calculate_average_productivity()
        
        # Labor demand
        if self.A2 > 0:
            self.Ld = int(self.Q2 / self.A2 * (1 + self.model.theta))
        else:
            self.Ld = 0
        
        # Desired capital
        if self.A2 > 0:
            self.Kd = int(self.Q2 / (self.model.u * self.model.m2 * self.A2))
        else:
            self.Kd = self.K
        
        # Investment demand for expansion
        Id = max(self.Kd - self.K, 0)  # Expansion only
        
        # CRITICAL FIX: Replacement investment following C++ logic
        # Scrap machines that are either:
        # 1. Beyond technical lifetime (age >= eta), OR
        # 2. Economically obsolete (payback < b for replacement)
        # BUT: Only scrap if we can afford to replace or if past technical life
        t = self.model.steps
        w2avg = self.model.get_sector2_avg_wage()
        
        # Check financial capacity for replacement
        available_finance = max(self.NW + self.Debmax - self.Deb, 0)
        p1_avg = self.model.get_avg_price_sector1()
        max_affordable_machines = int(available_finance / p1_avg) if p1_avg > 0 else 0
        
        machines_to_scrap = []
        for vintage in self.vintages[:]:
            vintage.age = t - vintage.t0
            
            # Check technical lifetime - MUST scrap if beyond eta
            if vintage.age >= self.model.eta:
                machines_to_scrap.append((vintage, vintage.machines, True))  # forced=True
            elif self.supplier and max_affordable_machines > 0:
                # Check economic replacement only if we can afford it
                new_A = self.supplier.Atau
                old_A = vintage.A
                
                if w2avg > 0 and new_A > old_A:
                    cost_savings = w2avg / old_A - w2avg / new_A
                    if cost_savings > 0:
                        payback = (self.supplier.p1 / self.model.m2) / cost_savings
                        if payback < self.model.b:
                            # Economically worthwhile to replace - but limit by affordability
                            machines_to_scrap.append((vintage, vintage.machines, False))  # forced=False
        
        # Process scrapping - prioritize forced scrapping
        for vintage, machines, forced in machines_to_scrap:
            if forced:
                # Must scrap regardless of finances
                Id += machines
                self.K -= machines
                if vintage in self.vintages:
                    self.vintages.remove(vintage)
            elif max_affordable_machines >= machines:
                # Can afford to replace
                Id += machines
                self.K -= machines
                max_affordable_machines -= machines
                if vintage in self.vintages:
                    self.vintages.remove(vintage)
            # else: skip economic replacement if can't afford
        
        # Ensure K doesn't go negative
        self.K = max(self.K, 0)
        
        # If no vintages left, add minimal capital
        if len(self.vintages) == 0 and self.supplier:
            min_machines = 1
            new_vintage = Vintage(
                IDvint=t * 10000 + self.supplier.ID,
                t0=t,
                supplier_id=self.supplier.ID,
                A=self.supplier.Atau,
                machines=min_machines
            )
            self.vintages.append(new_vintage)
            self.K = min_machines
            Id = max(Id - min_machines, 0)  # Adjust Id since we added machines
        
        # Order machines with financial constraints
        if Id > 0 and self.supplier:
            # Recalculate available finance
            available_finance = max(self.NW + self.Debmax - self.Deb, 0)
            p1_avg = self.model.get_avg_price_sector1()
            if p1_avg > 0:
                Id = min(Id, int(available_finance / p1_avg))
            
            self.machine_order = max(int(Id), 0)
        else:
            self.machine_order = 0
    
    def calculate_average_productivity(self) -> float:
        """Calculate weighted average productivity of capital stock"""
        if len(self.vintages) == 0 or self.K == 0:
            return self.model.initial_productivity
        
        total_prod = 0
        total_machines = 0
        
        for vintage in self.vintages:
            total_prod += vintage.A * vintage.machines
            total_machines += vintage.machines
        
        if total_machines > 0:
            return total_prod / total_machines
        else:
            return self.model.initial_productivity
    
    def hire_fire_workers(self):
        """Hire or fire workers following sector-specific rules"""
        shortage = max(self.Ld - self.L, 0)
        surplus = max(self.L - self.Ld, 0)
        
        # Hire
        if shortage > 0 and len(self.applications) > 0:
            applications = self.sort_applications(self.applications, HiringOrder(self.model.flagHireOrder2))
            self.wage_offer = self.calculate_wage_offer(applications, self.model.flagWageOffer)
            
            hired = 0
            for app in applications:
                if hired >= shortage:
                    break
                if app['wage'] <= self.wage_offer:
                    # Assign to vintage
                    vintage = self.assign_worker_to_vintage()
                    self.hire_worker(app['worker'], self.wage_offer, vintage)
                    app['worker'].employed = 2
                    if vintage:
                        vintage.workers.append(app['worker'])
                    hired += 1
        
        # Fire based on firing rule
        if surplus > 0:
            rule = FiringRule(self.model.flagFireRule)
            
            if rule == FiringRule.NEVER_FIRE_JAPANESE:
                pass  # Don't fire
            
            elif rule == FiringRule.NEVER_FIRE_SHARING_GERMAN:
                # Work sharing - reduce hours (not implemented in detail)
                pass
            
            elif rule == FiringRule.ONLY_DOWNSIZING_FRENCH:
                if self.K < self.Kd:  # Downsizing
                    self.fire_surplus_workers(surplus)
            
            elif rule == FiringRule.ONLY_LOSSES_ITALIAN:
                if self.Pi < 0:  # Losses
                    self.fire_surplus_workers(surplus)
            
            elif rule == FiringRule.PAYBACK_AMERICAN:
                # Fire by payback period
                self.fire_by_payback(surplus)
            
            elif rule == FiringRule.ALWAYS_FIRE_BRAZILIAN:
                self.fire_surplus_workers(surplus)
        
        self.clear_applications()
    
    def assign_worker_to_vintage(self) -> Optional[Vintage]:
        """Assign worker to a vintage (prefer newest)"""
        if len(self.vintages) == 0:
            return None
        
        # Assign to vintage with most machines and fewest workers
        best_vintage = None
        best_ratio = -1
        
        for vintage in self.vintages:
            if vintage.machines > 0:
                ratio = vintage.machines / max(len(vintage.workers), 1)
                if ratio > best_ratio:
                    best_ratio = ratio
                    best_vintage = vintage
        
        return best_vintage
    
    def fire_surplus_workers(self, surplus: int):
        """Fire surplus workers in firing order"""
        workers_sorted = self.sort_workers_for_firing(HiringOrder(self.model.flagFireOrder2))
        for worker in workers_sorted[:surplus]:
            self.fire_worker(worker)
            # Remove from vintage
            if worker.vintage and worker in worker.vintage.workers:
                worker.vintage.workers.remove(worker)
    
    def fire_by_payback(self, surplus: int):
        """Fire workers with lowest payback"""
        # Simplified: fire lowest productivity workers
        workers_by_prod = sorted(self.workers, key=lambda w: w.sV * w.sT)
        for worker in workers_by_prod[:surplus]:
            self.fire_worker(worker)
            if worker.vintage and worker in worker.vintage.workers:
                worker.vintage.workers.remove(worker)
    
    def sort_workers_for_firing(self, order: HiringOrder) -> List[Worker]:
        """Sort workers for firing"""
        if order == HiringOrder.RANDOM:
            return self.random.sample(self.workers, len(self.workers))
        elif order == HiringOrder.HIGHER_WAGE_FIRST:
            return sorted(self.workers, key=lambda w: w.w, reverse=True)
        elif order == HiringOrder.LOWER_WAGE_FIRST:
            return sorted(self.workers, key=lambda w: w.w)
        elif order == HiringOrder.HIGHER_SKILLS_FIRST:
            return sorted(self.workers, key=lambda w: w.sV * w.sT, reverse=True)
        elif order == HiringOrder.LOWER_SKILLS_FIRST:
            return sorted(self.workers, key=lambda w: w.sV * w.sT)
        elif order == HiringOrder.OLD_HIRED_FIRST:
            return sorted(self.workers, key=lambda w: w.Te, reverse=True)
        elif order == HiringOrder.RECENT_HIRED_FIRST:
            return sorted(self.workers, key=lambda w: w.Te)
        else:
            return self.workers
    
    def produce(self):
        """Produce consumer goods"""
        L2e = len(self.workers)
        
        self.Q2e = 0
        for vintage in self.vintages:
            if len(vintage.workers) > 0:
                # Calculate average skills
                avg_skills = np.mean([w.sV * w.sT for w in vintage.workers])
                productivity = vintage.A * avg_skills if self.model.flagWorkerSkProd else vintage.A
                
                # Production limited by machines or workers
                output = min(vintage.machines * self.model.m2,
                           len(vintage.workers) * productivity)
                self.Q2e += output
        
        self.Q2e = min(self.Q2e, self.Q2)
    
    def set_price(self):
        """Set price using adaptive markup"""
        # Calculate unit cost
        W2 = sum(w.w for w in self.workers)
        if self.Q2e > 0:
            self.c2 = W2 / self.Q2e
        else:
            # No production - maintain previous cost or use average
            if self.c2 <= 0:
                self.c2 = self.model.get_avg_unit_cost_sector2()
        
        # Ensure unit cost is positive
        self.c2 = max(self.c2, self.model.w0min * 0.5)
        
        # Adaptive markup
        if self.life_cycle > 1:
            f_prev = getattr(self, 'f_prev', self.f)
            f_prev2 = getattr(self, 'f_prev2', f_prev)
            
            if self.f > f_prev:
                self.mu2 = self.mu2 * (1 + self.model.upsilon)
            elif self.f < f_prev:
                self.mu2 = self.mu2 * (1 - self.model.upsilon)
            
            self.f_prev2 = f_prev
            self.f_prev = self.f
        
        # Bound markup to prevent extreme prices
        self.mu2 = np.clip(self.mu2, 0.01, 2.0)
        
        # Calculate price with safety bounds
        self.p2 = (1 + self.mu2) * self.c2
        
        # Ensure price is reasonable
        avg_price = self.model.get_avg_price_sector2()
        if avg_price > 0:
            # Prevent extreme price deviations
            self.p2 = np.clip(self.p2, avg_price * 0.1, avg_price * 10)
        else:
            # Fallback if no valid average
            self.p2 = max(self.p2, self.model.w0min)
    
    def update_competitiveness(self):
        """Update firm competitiveness"""
        # Normalize price (inverse for competitiveness)
        p2_avg = self.model.get_avg_price_sector2()
        price_comp = 1 - (self.p2 / p2_avg) if p2_avg > 0 else 0
        
        # Unfilled demand ratio (inverse for competitiveness)
        unfilled_ratio = self.unfilled_demand / max(self.D2d, 1) if self.D2d > 0 else 0
        unfilled_comp = 1 - unfilled_ratio
        
        # Quality (simplified - could be based on productivity)
        quality_comp = self.quality
        
        # Weighted competitiveness
        self.E = (self.model.omega1 * price_comp + 
                 self.model.omega2 * unfilled_comp +
                 self.model.omega3 * quality_comp)
    
    def compute_financials(self):
        """Compute financial results"""
        # Sales (from fulfilled demand)
        self.S = self.p2 * self.D2
        
        # Wage bill
        W2 = sum(w.w for w in self.workers)
        
        # Profits (simplified - no depreciation detail)
        self.Pi = self.S - W2
        
        # Taxes
        self.Tax = max(self.model.tr * self.Pi, 0)
        
        # Bonuses (profit sharing for top firms)
        Pi2_avg = self.model.get_avg_profit_sector2()
        if self.Pi > Pi2_avg and len(self.workers) > 0:
            self.Bon2 = self.model.psi6 * (self.Pi - self.Tax)
            # Distribute to workers proportional to wage
            total_wages = sum(w.w for w in self.workers)
            if total_wages > 0:
                for worker in self.workers:
                    worker.bonus = self.Bon2 * worker.w / total_wages
        else:
            self.Bon2 = 0
            for worker in self.workers:
                worker.bonus = 0
        
        # Dividends
        self.Div = max(self.model.d2 * (self.Pi - self.Tax - self.Bon2), 0)
        
        # Update net worth
        self.NW = self.NW + self.Pi - self.Tax - self.Div - self.Bon2
        
        # Update inventories
        self.N = self.N + self.Q2e - self.D2
        
        # Update debt limit
        self.Debmax = self.model.Lambda * max(self.NW, self.S - W2)
    
    def receive_machines(self, quantity: int):
        """Receive machines from supplier"""
        if quantity > 0 and self.supplier:
            new_vintage = Vintage(
                IDvint=self.model.steps * 10000 + self.supplier.ID,
                t0=self.model.steps,
                supplier_id=self.supplier.ID,
                A=self.supplier.Atau,
                machines=quantity
            )
            self.vintages.append(new_vintage)
            self.K += quantity
    
    def step(self):
        """Firm2 step"""
        self.life_cycle += 1
        
        # Age vintages
        for vintage in self.vintages:
            vintage.age += 1


# ============================================================================
# Bank Agent
# ============================================================================

class Bank(mesa.Agent):
    """
    Commercial bank agent
    
    Takes deposits, provides loans, manages reserves, evaluates credit risk.
    """
    
    def __init__(self, unique_id: int, model: 'KSModel'):
        super().__init__(model)
        
        # Identity
        self.ID = unique_id
        self.unique_id = unique_id
        
        # Balance sheet
        self.NWb = 0.0  # Net worth
        self.Depo = 0.0  # Deposits
        self.Loans = 0.0  # Total loans
        self.LoansCB = 0.0  # Loans from central bank
        self.Res = 0.0  # Required reserves
        self.ExRes = 0.0  # Excess reserves
        self.BondsB = 0.0  # Government bonds
        
        # Clients
        self.clients1: List[Firm1] = []
        self.clients2: List[Firm2] = []
        
        # Financial results
        self.PiB = 0.0  # Profits
        self.TaxB = 0.0  # Taxes
        self.DivB = 0.0  # Dividends
        self.BadDeb = 0.0  # Bad debt
        
        # Market share
        self.fD = 0.0  # Deposit market share
        self.fB = 0.0  # Client market share
        
        # Initialize
        self.initialize_bank()
    
    def initialize_bank(self):
        """Initialize bank"""
        # Initial equity as fraction of total firm equity
        total_NW = (self.model.F10 * self.model.NW10 + 
                   self.model.F20 * self.model.NW20)
        self.NWb = self.model.EqB0 * total_NW / max(self.model.B, 1)
        self.fB = 1.0 / max(self.model.B, 1)
        self.fD = 1.0 / max(self.model.B, 1)
    
    def collect_deposits(self):
        """Collect deposits from workers and firms"""
        self.Depo = 0
        
        # Worker deposits (share of savings)
        self.Depo += self.fD * self.model.SavAcc
        
        # Firm deposits
        for client in self.clients1 + self.clients2:
            self.Depo += max(client.NW, 0)
    
    def evaluate_credit_requests(self):
        """Evaluate and rank clients for credit allocation"""
        # Create pecking order
        rank1 = [(client, client.NW / max(client.S, 0.01)) for client in self.clients1 if client.S > 0]
        rank2 = [(client, client.NW / max(client.S, 0.01)) for client in self.clients2 if client.S > 0]
        
        rank1.sort(key=lambda x: x[1], reverse=True)
        rank2.sort(key=lambda x: x[1], reverse=True)
        
        # Assign credit classes (quartiles)
        for i, (client, ratio) in enumerate(rank1):
            if i < len(rank1) * 0.25:
                client.qc = 1
            elif i < len(rank1) * 0.5:
                client.qc = 2
            elif i < len(rank1) * 0.75:
                client.qc = 3
            else:
                client.qc = 4
        
        for i, (client, ratio) in enumerate(rank2):
            if i < len(rank2) * 0.25:
                client.qc = 1
            elif i < len(rank2) * 0.5:
                client.qc = 2
            elif i < len(rank2) * 0.75:
                client.qc = 3
            else:
                client.qc = 4
    
    def supply_credit(self):
        """Supply credit to firms based on pecking order"""
        # Credit supply limit
        if self.model.flagCreditRule == 0:
            credit_limit = np.inf
        elif self.model.flagCreditRule == 1:
            credit_limit = self.model.Lambda * self.Depo
        elif self.model.flagCreditRule == 2:
            # Basel-like
            credit_limit = self.Depo / self.model.tauB if self.model.tauB > 0 else np.inf
        else:
            credit_limit = np.inf
        
        credit_available = max(credit_limit - self.Loans, 0)
        
        # Combine and sort all clients by credit quality
        all_clients = [(c, c.qc, c.CD) for c in self.clients1 + self.clients2 if c.CD > 0]
        all_clients.sort(key=lambda x: x[1])  # Sort by credit class
        
        # Allocate credit
        for client, qc, CD_requested in all_clients:
            credit_requested = min(CD_requested, client.Debmax - client.Deb)
            credit_supplied = min(credit_requested, credit_available)
            
            if credit_supplied > 0:
                client.Deb += credit_supplied
                client.CS = credit_supplied
                self.Loans += credit_supplied
                credit_available -= credit_supplied
            
            if credit_supplied < credit_requested:
                client.CD_constrained = True
    
    def compute_financials(self):
        """Compute bank financial results"""
        # Interest income from loans
        iLb = self.Loans * self.model.rDeb
        
        # Interest payments on deposits
        iDb = self.Depo * self.model.rD
        
        # Interest on reserves and CB loans
        iCBb = self.Res * self.model.rRes + self.LoansCB * self.model.r
        
        # Profits
        self.PiB = iLb - iDb - iCBb - self.BadDeb
        
        # Taxes
        self.TaxB = max(self.model.tr * self.PiB, 0)
        
        # Dividends
        self.DivB = max(self.model.dB * (self.PiB - self.TaxB), 0)
        
        # Update net worth
        self.NWb = self.NWb + self.PiB - self.TaxB - self.DivB
        
        # Reset bad debt
        self.BadDeb = 0
    
    def manage_reserves(self):
        """Manage required and excess reserves"""
        # Required reserves
        self.Res = self.model.tauB * self.Depo
        
        # Calculate excess reserves (simplified)
        self.ExRes = self.NWb + self.Depo - self.Loans - self.Res
        
        # Manage liquidity
        if self.ExRes < 0:
            # Request loan from central bank
            self.LoansCB += -self.ExRes
            self.ExRes = 0
    
    def add_bad_debt(self, amount: float):
        """Add bad debt from client bankruptcy"""
        self.BadDeb += amount
        self.Loans -= amount
    
    def bailout_condition(self) -> bool:
        """Check if bank needs bailout"""
        return self.NWb < 0
    
    def step(self):
        """Bank step"""
        pass


# Make sure all classes are exported
__all__ = ['Worker', 'Firm1', 'Firm2', 'Bank', 'Vintage',
           'SearchMode', 'SearchDiscouragement', 'HiringSequence',
           'HiringOrder', 'FiringRule', 'ExpectationMode']
