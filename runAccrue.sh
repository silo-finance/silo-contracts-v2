# certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing0DoesntAffectShareBalance --msg "accruing0DoesntAffectShareBalance"
# certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing1DoesntAffectShareBalance --msg "accruing1DoesntAffectShareBalance"
# certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing0DoesntAffectAssetsBalance --msg "accruing0DoesntAffectAssetsBalance"
# certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing1DoesntAffectAssetsBalance --msg "accruing1DoesntAffectAssetsBalance"
# certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing0DoesntAffectTotalAssets --msg "accruing0DoesntAffectTotalAssets"
# certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing1DoesntAffectTotalAssets --msg "accruing1DoesntAffectTotalAssets"

certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing0DoesntAffectShareBalance --msg "mut2 accruing0DoesntAffectShareBalance"
certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing1DoesntAffectShareBalance --msg "mut2 accruing1DoesntAffectShareBalance"
certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing0DoesntAffectAssetsBalance --msg "mut2 accruing0DoesntAffectAssetsBalance"
certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing1DoesntAffectAssetsBalance --msg "mut2 accruing1DoesntAffectAssetsBalance"
certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing0DoesntAffectTotalAssets --msg "mut2 accruing0DoesntAffectTotalAssets"
certoraRun.py certora/config/silo/newRulesFromTheList.conf --verify "Silo0:certora/specs/silo/accrue_otakar.spec" --rule accruing1DoesntAffectTotalAssets --msg "mut2 accruing1DoesntAffectTotalAssets"