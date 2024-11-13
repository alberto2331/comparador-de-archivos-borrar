ALTER PROCEDURE [dbo].[SP_GetPrevFYLastBCForms] (
	@FormTenantId int,
	@FormLosId int,
	@PrevFormManagerId int,
	@FormCurrencyId int,
	@CustomerOrGeId int,
	@IsCustomer bit,
	@FormToEdit int,
	@MaxCustomerLength int,
	@MaxDescriptionLength int
)
AS
BEGIN
	DECLARE @CurrentFYDateFrom datetime2;
	DECLARE @PrevFYId int
	DECLARE @PrevFYLastBCId int;
	SET @CurrentFYDateFrom = (SELECT TOP 1 fy.DateFrom  
	FROM [dbo].[BudgetCycles] bc
	inner join [dbo].[FiscalYears] fy on bc.FiscalYearId = fy.Id
	WHERE bc.Enabled = 1
	and bc.Closed = 0
	and bc.FromDate <= CAST(GETDATE() AS DATE)
	and bc.ToDate >= CAST(GETDATE() AS DATE)
	and bc.DeletedDate is null
	and bc.TenantId = @FormTenantId
	and bc.LosId = @FormLosId)

	SET @PrevFYId  = (SELECT TOP 1 Id FROM FiscalYears 
		WHERE DateTo < @CurrentFYDateFrom
		and TenantId = @FormTenantId
		and DeletedDate is null
		ORDER BY DateTo desc
	)

	SET @PrevFYLastBCId = (SELECT TOP 1 bc.Id FROM BudgetCycles bc join BudgetCycleTypes bct on bc.BudgetCycleTypeId = bct.id
		WHERE Tenantid = @FormTenantId
		and LosId = @FormLosid
		and bc.DeletedDate is null and bct.DeletedDate is null
		and Enabled = 1
		and FiscalYearId = @PrevFYId
		ORDER BY bct.[Order] desc
	)

	SELECT F.Id, 
	CONCAT(F.Id, ' - ', fn.CustomerOrGeDescription, ' - ', F.Name) as Description,
	CASE 
		WHEN LEN(fn.ShortenedDescription) > @MaxDescriptionLength THEN LEFT(fn.ShortenedDescription, @MaxDescriptionLength -3) + '...'
		ELSE fn.ShortenedDescription
	END as ShortenedDescription
	FROM Form f
	LEFT JOIN Customers c ON f.CustomerId = c.id
	LEFT JOIN EconomicGroups eg ON f.EconomicGroupId = eg.id 
	OUTER APPLY (
		SELECT *,
		CONCAT(F.Id, ' - ', temp2.ShortenedCustomer, ' - ', F.Name) AS ShortenedDescription 
		FROM 
		(
			SELECT temp.CustomerOrGeDescription,
			CASE
				WHEN LEN(temp.CustomerOrGeDescription) > @MaxCustomerLength 
				THEN LEFT(temp.CustomerOrGeDescription, @MaxCustomerLength -3) + '...' 
				ELSE temp.CustomerOrGeDescription
			END as ShortenedCustomer
			FROM (
				SELECT CASE
					WHEN F.CustomerOrEconomicGroupType = 1 THEN C.Description
					WHEN F.CustomerOrEconomicGroupType = 2 THEN eg.Description
				END AS CustomerOrGeDescription
			) temp
		) temp2
	) fn
	WHERE F.BudgetCycleId = @PrevFYLastBCId 
	AND F.DeletedDate is null 
	AND F.FormTypeId = 1
	AND F.IsValidPricing = 1
	AND F.ManagerId = @PrevFormManagerId
	AND F.CurrencyId = @FormCurrencyId
	AND (
		(@IsCustomer =1 AND F.CustomerOrEconomicGroupType = 1 AND F.CustomerId = @CustomerOrGeId) OR 
		(@IsCustomer = 0 AND F.CustomerOrEconomicGroupType = 2 AND F.EconomicGroupId = @CustomerOrGeId)
	)
	AND f.StatusId = 7
	AND F.id not in (
		SELECT DISTINCT f2.PrevFiscalYearFormId from Form f2
		WHERE f2.DeletedDate is null 
		AND f2.PrevFiscalYearFormId is not null
		AND f2.FormTypeId = 1
		AND (@FormToEdit is null OR f2.Id <> @FormToEdit)
	) 
	ORDER BY Description
END
