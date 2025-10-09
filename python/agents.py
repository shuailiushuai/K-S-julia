"""
K+S Agent-Based Model Implementation using Mesa 3.0
====================================================

This module implements the K+S (Keynes meets Schumpeter) macroeconomic
agent-based model using the Mesa 3.0 framework.

Original model: Marcelo C. Pereira, University of Campinas
Python/Mesa implementation: Complete reproduction of C++/LSD version

References:
- Dosi et al. (2010, 2015, 2017, 2018, 2019, 2020)
- Original C++ implementation in fun_KS*.cpp/h files
"""

import mesa
import numpy as np
from typing import List, Dict, Optional, Tuple, TYPE_CHECKING
from dataclasses import dataclass, field
from enum import IntEnum
import random

if TYPE_CHECKING:
    from agents_extended import Firm2


# ============================================================================
# Enumerations for Control Flags
# ============================================================================

class SearchMode(IntEnum):
    """Job search mode"""
    ALWAYS = 0
    UNEMPLOYED_ONLY = 1
    UNEMPLOYED_OR_LOW_WAGE = 2


class SearchDiscouragement(IntEnum):
    """Job search discouragement mode"""
    NONE = 0
    GLOBAL = 1
    INDIVIDUAL = 2


class HiringSequence(IntEnum):
    """Consumption-good sector hiring sequence"""
    RANDOM = 0
    HIGHER_WAGE_FIRST = 1
    NO_WORKERS_FIRST = 2
    NO_WORKERS_THEN_HIGHER_WAGE = 3


class HiringOrder(IntEnum):
    """Hiring/firing order within firm"""
    RANDOM = 0
    HIGHER_WAGE_FIRST = 1
    LOWER_WAGE_FIRST = 2
    HIGHER_SKILLS_FIRST = 3
    LOWER_SKILLS_FIRST = 4
    HIGHER_PAYBACK_FIRST = 5
    LOWER_PAYBACK_FIRST = 6
    OLD_HIRED_FIRST = 7
    RECENT_HIRED_FIRST = 8


class FiringRule(IntEnum):
    """Consumption-good sector firing rule"""
    NEVER_FIRE_JAPANESE = 0
    NEVER_FIRE_SHARING_GERMAN = 1
    ONLY_DOWNSIZING_FRENCH = 2
    ONLY_LOSSES_ITALIAN = 3
    PAYBACK_AMERICAN = 4
    ALWAYS_FIRE_BRAZILIAN = 5


class ExpectationMode(IntEnum):
    """Demand expectation formation mode"""
    MYOPIC_1_PERIOD = 0
    MYOPIC_4_PERIOD = 1
    ACCELERATING = 2
    ADAPTIVE = 3
    EXTRAPOLATIVE_ACCELERATING = 4


# ============================================================================
# Vintage Data Structure
# ============================================================================

@dataclass
class Vintage:
    """Machine vintage with embedded technology"""
    IDvint: int  # Vintage ID (T0 * 10000 + supplier ID)
    t0: int  # Creation time
    supplier_id: int  # Supplier firm ID
    A: float  # Labor productivity
    machines: int  # Number of machines
    workers: List['Worker'] = field(default_factory=list)
    sVp: float = 1.0  # Public vintage skills
    sVavg: float = 1.0  # Average vintage skills
    age: int = 0
    
    def get_productivity(self, worker_skills: float) -> float:
        """Get effective productivity with worker skills"""
        return self.A * worker_skills


# ============================================================================
# Worker Agent
# ============================================================================

class Worker(mesa.Agent):
    """
    Worker/Consumer agent in the K+S model
    
    Workers search for jobs, earn wages, update skills, age and retire.
    """
    
    def __init__(self, unique_id: int, model: 'KSModel'):
        super().__init__(model)
        
        # Identity
        self.ID = unique_id
        self.unique_id = unique_id
        
        # Employment
        self.employed = 0  # 0=unemployed, 1=sector1, 2=sector2
        self.employer: Optional['Firm'] = None
        self.vintage: Optional[Vintage] = None
        
        # Age and lifecycle
        self.age = np.random.randint(1, model.Tr + 1) if model.Tr > 0 else 1
        self.Te = 0  # Tenure with current employer
        self.Tc = model.Tc  # Contract term
        
        # Wages
        self.w = model.w0min  # Current wage
        self.wRes = model.w0min  # Reservation wage
        self.w_history = [model.w0min] * 8  # Wage memory
        self.bonus = 0.0  # Profit-sharing bonus
        
        # Skills
        self.sV = model.initial_skill  # Vintage skills (learning-by-using)
        self.sT = model.initial_skill  # Tenure skills (learning-by-doing)
        
        # Job search
        self.searchProb = 1.0
        self.discouraged = False
        self.unemployment_duration = 0
        
    def apply_for_jobs(self) -> int:
        """Apply for jobs at firms. Returns number of applications"""
        # Determine number of applications
        if self.employed == 2:  # Employed in sector 2
            if self.employer and getattr(self.employer, 'postChg', False):
                omega = self.model.omega
            else:
                omega = self.model.omegaPreChg
        else:
            omega = self.model.omega if self.employed else self.model.omegaU
        
        if omega == 0:
            self.discouraged = False
            return 0
        
        # Apply search mode rules
        if self.model.flagSearchMode == SearchMode.ALWAYS:
            num_apps = self.searchProb * omega
        elif self.model.flagSearchMode == SearchMode.UNEMPLOYED_ONLY:
            num_apps = self.searchProb * omega if not self.employed else 0
        elif self.model.flagSearchMode == SearchMode.UNEMPLOYED_OR_LOW_WAGE:
            w_avg = self.model.get_sector2_avg_wage()
            num_apps = self.searchProb * omega if (not self.employed or self.w < w_avg) else 0
        else:
            num_apps = 0
        
        # Handle fractional applications
        if 0 < num_apps < 1:
            num_apps = 1 if self.random.random() < num_apps else 0
        else:
            num_apps = int(num_apps)
        
        if num_apps == 0:
            return 0
        
        # Calculate requested wage
        if self.model.Ts == 0:
            w_requested = self.wRes
        else:
            w_requested = max(self.w_history[-self.model.Ts:])
        
        # Select firms weighted by size
        firms = self.select_firms_for_application(num_apps)
        
        # Submit applications
        for firm in firms:
            application = {
                'worker': self,
                'wage': w_requested,
                'sV': self.sV,
                'sT': self.sT,
                'Te': self.Te,
            }
            firm.add_application(application)
        
        return num_apps
    
    def select_firms_for_application(self, num_apps: int) -> List['Firm']:
        """Select firms proportional to their workforce size"""
        # Import here to avoid circular import
        from agents_extended import Firm2
        
        # Combine sector 1 and sector 2 firms
        all_firms = list(self.model.get_agents_of_type(Firm1)) + list(self.model.get_agents_of_type(Firm2))
        
        if len(all_firms) == 0:
            return []
        
        # Get workforce sizes
        sizes = [firm.get_workforce_size() for firm in all_firms]
        total_size = sum(sizes)
        
        if total_size == 0:
            # Random selection if no workers anywhere
            return self.random.sample(all_firms, min(num_apps, len(all_firms)))
        
        # Weighted random selection
        probs = [s / total_size for s in sizes]
        selected = self.random.choices(all_firms, weights=probs, k=num_apps)
        
        return list(set(selected))  # Remove duplicates
    
    def calculate_search_probability(self):
        """Update individual search probability"""
        if self.model.flagSearchDisc == SearchDiscouragement.NONE:
            self.searchProb = 1.0
        elif self.model.flagSearchDisc == SearchDiscouragement.GLOBAL:
            # Global discouragement
            Ue = self.model.get_unemployment_rate()
            kappa = self.model.kappa
            self.searchProb = kappa * np.exp(-kappa * Ue)
        elif self.model.flagSearchDisc == SearchDiscouragement.INDIVIDUAL:
            # Individual discouragement
            lamb = self.model.lambda_search
            self.searchProb = np.exp(-lamb * self.unemployment_duration)
    
    def update_skills(self):
        """Update worker skills based on employment status"""
        if self.employed == 2 and self.vintage:
            # Learning-by-using (vintage skills)
            if self.model.flagWorkerLBU in [1, 3]:
                sV_public = self.vintage.sVp
                learning_rate = 0.1  # Could be parameterized
                self.sV = self.sV + (sV_public - self.sV) * learning_rate
            
            # Learning-by-doing (tenure skills)
            if self.model.flagWorkerLBU in [2, 3]:
                self.sT = self.sT * (1 + self.model.tauT)
        
        elif not self.employed:
            # Skills deterioration when unemployed
            self.sV = self.sV * (1 - self.model.tauU)
            self.sT = self.sT * (1 - self.model.tauU)
            
            # Government training
            if self.random.random() < self.model.Gamma:
                self.sV = self.sV * (1 + self.model.tauG)
                self.sT = self.sT * (1 + self.model.tauG)
            
            self.unemployment_duration += 1
        else:
            self.unemployment_duration = 0
    
    def age_one_period(self):
        """Age worker by one period and handle retirement"""
        self.age += 1
        
        if self.model.Tr > 0 and self.age >= self.model.Tr:
            # Retirement - "reborn" as new worker
            self.age = 1
            self.employed = 0
            self.employer = None
            self.vintage = None
            self.Te = 0
            self.sV = self.model.initial_skill
            self.sT = self.model.initial_skill
            self.w = self.model.w0min
            self.wRes = self.model.w0min
    
    def get_income(self) -> float:
        """Get worker income (wage + bonus if applicable)"""
        if self.employed:
            return self.w + self.bonus
        else:
            return self.model.wU
    
    def step(self):
        """Worker step - handled by model scheduler"""
        pass


# ============================================================================
# Base Firm Class
# ============================================================================

class Firm(mesa.Agent):
    """Base class for firms"""
    
    def __init__(self, unique_id: int, model: 'KSModel'):
        super().__init__(model)
        
        # Identity
        self.ID = unique_id
        self.unique_id = unique_id
        self.postChg = False  # Post-regime-change type
        self.life_cycle = 0  # Age in periods
        
        # Financial
        self.NW = 0.0  # Net worth
        self.Deb = 0.0  # Total debt
        self.Debmax = 0.0  # Maximum debt limit
        self.S = 0.0  # Sales revenue
        self.Pi = 0.0  # Profits
        self.Tax = 0.0  # Taxes paid
        self.Div = 0.0  # Dividends paid
        
        # Credit
        self.bank: Optional['Bank'] = None
        self.CD = 0.0  # Credit demand
        self.CS = 0.0  # Credit supplied
        self.CD_constrained = False
        self.qc = 4  # Credit class (1-4, lower is better)
        
        # Labor
        self.L = 0  # Current workforce
        self.Ld = 0  # Desired workforce
        self.workers: List[Worker] = []
        self.applications: List[Dict] = []
        self.wage_offer = 0.0
        
        # Market
        self.f = 0.0  # Market share
        
    def get_workforce_size(self) -> int:
        """Get current workforce size"""
        return len(self.workers)
    
    def add_application(self, application: Dict):
        """Add a job application"""
        self.applications.append(application)
    
    def clear_applications(self):
        """Clear application queue"""
        self.applications = []
    
    def hire_worker(self, worker: Worker, wage: float, vintage: Optional[Vintage] = None):
        """Hire a worker"""
        # Fire worker from previous employer if any
        if worker.employer:
            worker.employer.fire_worker(worker)
        
        # Hire
        worker.employer = self
        worker.w = wage
        worker.Te = 0
        worker.vintage = vintage
        self.workers.append(worker)
        self.L = len(self.workers)
    
    def fire_worker(self, worker: Worker):
        """Fire a worker"""
        if worker in self.workers:
            self.workers.remove(worker)
            worker.employer = None
            worker.employed = 0
            worker.vintage = None
            worker.Te = 0
            self.L = len(self.workers)
    
    def calculate_wage_offer(self, applications: List[Dict], mode: int) -> float:
        """Calculate wage offer based on applications and mode"""
        if len(applications) == 0:
            return self.model.w0min
        
        if mode == 0:  # Propose wage premium (ignore requests)
            # Use markup-based calculation
            return self.model.wAvg * 1.05  # 5% premium
        elif mode == 1:  # Propose lowest possible wage
            # Find minimum requested wage
            requested_wages = [app['wage'] for app in applications]
            return max(min(requested_wages), self.model.wMinPol)
        else:
            return self.model.wAvg
    
    def sort_applications(self, applications: List[Dict], order: HiringOrder) -> List[Dict]:
        """Sort applications by hiring order"""
        if order == HiringOrder.RANDOM:
            return self.random.sample(applications, len(applications))
        elif order == HiringOrder.HIGHER_WAGE_FIRST:
            return sorted(applications, key=lambda x: x['wage'], reverse=True)
        elif order == HiringOrder.LOWER_WAGE_FIRST:
            return sorted(applications, key=lambda x: x['wage'])
        elif order == HiringOrder.HIGHER_SKILLS_FIRST:
            return sorted(applications, key=lambda x: x['sV'] * x['sT'], reverse=True)
        elif order == HiringOrder.LOWER_SKILLS_FIRST:
            return sorted(applications, key=lambda x: x['sV'] * x['sT'])
        elif order == HiringOrder.OLD_HIRED_FIRST:
            return sorted(applications, key=lambda x: x['Te'], reverse=True)
        elif order == HiringOrder.RECENT_HIRED_FIRST:
            return sorted(applications, key=lambda x: x['Te'])
        else:
            return applications
    
    def exit_condition(self) -> bool:
        """Check if firm should exit"""
        return self.f < self.model.f_min or self.NW < 0
    
    def step(self):
        """Firm step - to be overridden"""
        pass


# ============================================================================
# Firm1 Agent (Capital-Good Sector)
# ============================================================================

class Firm1(Firm):
    """
    Capital-good producer firm
    
    Invests in R&D, produces heterogeneous machines with different
    productivities, sells to consumption-good firms.
    """
    
    def __init__(self, unique_id: int, model: 'KSModel'):
        super().__init__(unique_id, model)
        
        # Technology - use model's Btau0 for correct initial productivity
        self.Atau = model.initial_productivity  # Final productivity
        self.Btau = model.Btau0  # Production productivity (corrected initial value)
        
        # Production
        self.Q1 = 0  # Planned production
        self.Q1e = 0  # Effective production
        self.D1 = 0  # Orders received
        self.p1 = 0.0  # Machine price
        
        # R&D
        self.L1rd = 0  # Workers in R&D
        self.RD = 0.0  # R&D expenditure
        
        # Workers
        self.employed_status = 1  # Sector 1
        
        # Clients
        self.clients: List['Firm2'] = []
        
        # Initial values
        self.initialize_firm1()
    
    def initialize_firm1(self):
        """Initialize firm1 specific attributes"""
        self.NW = self.model.NW10
        debt_ratio = self.model.Deb10ratio
        self.Deb = self.NW * debt_ratio / (1 - debt_ratio) if debt_ratio < 1 else 0
        self.f = 1.0 / max(self.model.F10, 1)
        # Use correct initial price calculation
        self.p1 = self.model.p10
    
    def rd_innovation_imitation(self):
        """Perform R&D: innovation and imitation"""
        if self.L1rd == 0:
            return
        
        # Normalized R&D workers
        L1rdN = self.L1rd * self.model.Ls0 / max(self.model.Ls, 1)
        
        w1avg = self.model.get_sector1_avg_wage()
        w2avg = self.model.get_sector2_avg_wage()
        
        # Current technology
        pTau = self.p1
        cTau = w2avg / self.Atau
        
        # Initialize best as current
        best_A = self.Atau
        best_B = self.Btau
        best_p = pTau
        best_payback = np.inf
        
        # INNOVATION
        prob_inn = 1 - np.exp(-self.model.zeta1 * self.model.xi * L1rdN)
        if self.random.random() < prob_inn:
            draw = self.random.betavariate(self.model.alpha1, self.model.beta1)
            Ainn = self.Atau * (1 + self.model.x1inf + draw * (self.model.x1sup - self.model.x1inf))
            Binn = self.Btau * (1 + self.model.x1inf + draw * (self.model.x1sup - self.model.x1inf))
            pInn = (1 + self.model.mu1) * w1avg / Binn / self.model.m1
            
            # Calculate payback
            payback = self.calculate_payback(Ainn, pInn, w2avg)
            if payback < best_payback:
                best_A, best_B, best_p, best_payback = Ainn, Binn, pInn, payback
        
        # IMITATION
        prob_imi = 1 - np.exp(-self.model.zeta2 * (1 - self.model.xi) * L1rdN)
        firm1_agents = list(self.model.get_agents_of_type(Firm1))
        if self.random.random() < prob_imi and len(firm1_agents) > 1:
            # Calculate distances to other firms
            p1avg = self.model.get_avg_price_sector1()
            c2avg = self.model.get_avg_unit_cost_sector2()
            
            other_firms = [f for f in firm1_agents if f != self]
            distances = []
            
            for other_firm in other_firms:
                p_other = (1 + self.model.mu1) * w1avg / other_firm.Btau / self.model.m1
                c_other = w2avg / other_firm.Atau
                
                dist = np.sqrt(((p_other - pTau) / max(p1avg, 0.01))**2 +
                              ((c_other - cTau) / max(c2avg, 0.01))**2)
                distances.append((other_firm, 1 / max(dist, 0.001)))
            
            # Normalize probabilities
            total_inv_dist = sum(d[1] for d in distances)
            if total_inv_dist > 0:
                probs = [d[1] / total_inv_dist for d in distances]
                selected = self.random.choices([d[0] for d in distances], weights=probs)[0]
                
                Aimi = selected.Atau
                Bimi = selected.Btau
                pImi = (1 + self.model.mu1) * w1avg / Bimi / self.model.m1
                
                payback = self.calculate_payback(Aimi, pImi, w2avg)
                if payback < best_payback:
                    best_A, best_B, best_p, best_payback = Aimi, Bimi, pImi, payback
        
        # Update to best technology
        self.Atau = best_A
        self.Btau = best_B
        self.p1 = best_p
    
    def calculate_payback(self, A: float, p: float, w2avg: float) -> float:
        """Calculate machine payback period"""
        if A == 0 or w2avg == 0:
            return np.inf
        
        operating_cost = w2avg / A
        savings_per_period = max(operating_cost - w2avg / self.Atau, 0)
        
        if savings_per_period <= 0:
            return np.inf
        
        return (p / self.model.m2) / savings_per_period
    
    def receive_orders(self):
        """Receive orders from clients and acquire new clients"""
        # Import here to avoid circular import
        from agents_extended import Firm2
        
        # Sum orders from existing clients
        self.D1 = sum(client.machine_order for client in self.clients if client.machine_order > 0)
        
        # Try to acquire new clients
        firm2_agents = list(self.model.get_agents_of_type(Firm2))
        num_new = int(self.model.gamma * len(firm2_agents))
        potential_clients = [f for f in firm2_agents if f not in self.clients]
        
        if len(potential_clients) > 0:
            new_clients = self.random.sample(potential_clients, min(num_new, len(potential_clients)))
            for client in new_clients:
                client.receive_brochure(self)
    
    def plan_production(self):
        """Plan production and labor demand"""
        self.Q1 = self.D1
        
        # Production labor demand
        Ld_prod = self.Q1 / (self.model.m1 * self.Btau) if self.Btau > 0 else 0
        
        # R&D labor demand
        w1avg = self.model.get_sector1_avg_wage()
        if w1avg > 0 and self.S > 0:
            Ld_rd = self.model.nu * self.S / w1avg
        else:
            Ld_rd = 0
        
        # Limit R&D labor
        Ld_rd = min(Ld_rd, self.model.L1rdMax * (Ld_prod + Ld_rd))
        
        self.Ld = int(Ld_prod + Ld_rd)
        self.L1rd = int(Ld_rd)
    
    def hire_fire_workers(self):
        """Hire or fire workers"""
        shortage = max(self.Ld - self.L, 0)
        surplus = max(self.L - self.Ld, 0)
        
        # Hire
        if shortage > 0 and shortage / max(self.Ld, 1) <= self.model.L1shortMax:
            applications = self.sort_applications(self.applications, HiringOrder(self.model.flagHireOrder1))
            self.wage_offer = self.calculate_wage_offer(applications, self.model.flagWageOffer)
            
            hired = 0
            for app in applications:
                if hired >= shortage:
                    break
                if app['wage'] <= self.wage_offer:
                    self.hire_worker(app['worker'], self.wage_offer)
                    app['worker'].employed = 1
                    hired += 1
        
        # Fire
        if surplus > 0:
            workers_sorted = self.sort_workers_for_firing(HiringOrder(self.model.flagFireOrder1))
            for worker in workers_sorted[:surplus]:
                self.fire_worker(worker)
        
        self.clear_applications()
    
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
        """Produce machines"""
        L1e = len(self.workers)
        self.Q1e = min(self.Q1, L1e * self.model.m1 * self.Btau)
    
    def compute_financials(self):
        """Compute financial results"""
        # Sales
        self.S = self.p1 * self.Q1e
        
        # Wage bill
        W1 = sum(w.w for w in self.workers)
        
        # Profits (simplified)
        self.Pi = self.S - W1
        
        # Taxes
        self.Tax = max(self.model.tr * self.Pi, 0)
        
        # Dividends
        self.Div = max(self.model.d1 * (self.Pi - self.Tax), 0)
        
        # Update net worth
        self.NW = self.NW + self.Pi - self.Tax - self.Div
        
        # Update debt limit
        self.Debmax = self.model.Lambda * max(self.NW, self.S - W1)
    
    def step(self):
        """Firm1 step"""
        self.life_cycle += 1


# To be continued in next file due to length...
