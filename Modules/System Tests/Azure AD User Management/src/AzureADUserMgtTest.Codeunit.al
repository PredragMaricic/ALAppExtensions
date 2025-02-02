codeunit 132909 "Azure AD User Management Test"
{
    Permissions = TableData "User Property" = rimd;
    Subtype = Test;
    TestPermissions = NonRestrictive;
    EventSubscriberInstance = Manual;

    trigger OnRun()
    begin
        // [FEATURE] [SaaS] [Azure AD User Management]
    end;

    var
        EnvironmentInfo: Codeunit "Environment Information";
        AzureADUserManagementImpl: Codeunit "Azure AD User Mgmt. Impl.";
        AzureADGraphUser: Codeunit "Azure AD Graph User";
        LibraryAssert: Codeunit "Library Assert";
        MockGraphQuery: DotNet MockGraphQuery;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    [Scope('OnPrem')]
    procedure TestCodeunitRunNoSaaS()
    var
        User: Record User;
        AzureADUserManagementTest: Codeunit "Azure AD User Management Test";
        AzureADPlanTestLibrary: Codeunit "Azure AD Plan Test Library";
        AzureADPlan: Codeunit "Azure AD Plan";
        UserSecurityId: Guid;
    begin
        // [SCENARIO] Codeunit AzureADUserManagement exits immediately if not running in SaaS

        Initialize(AzureADUserManagementTest);
        AzureADPlanTestLibrary.DeleteAllUserPlan();

        // [GIVEN] Not running in SaaS
        EnvironmentInfo.SetTestabilitySoftwareAsAService(false);

        // [GIVEN] The Azure AD Graph contains a user with the AccountEnabled flag set to true
        UserSecurityId := CreateGuid();
        AzureADUserManagementTest.AddGraphUser(UserSecurityId);
        AzureADPlanTestLibrary.AssignUserToPlan(UserSecurityId, CreateGuid());

        // [GIVEN] The user record's state is disabled
        DisableUserAccount(UserSecurityId);

        // [WHEN] Running Azure AD User Management
        AzureADUserManagementImpl.Run(UserSecurityId);

        // [THEN] no error is thrown, the codeunit silently exits

        // [THEN] The user record is not updated
        User.Get(UserSecurityId);
        LibraryAssert.AreEqual(User.State::Disabled, User.State, 'The User record should not have been updated');

        // [THEN] The unassigned user plans are not removed
        LibraryAssert.AreNotEqual(false, AzureADPlan.DoesUserHavePlans(UserSecurityId),
            'The User Plan table should not be empty for this user');

        UnbindSubscription(AzureADUserManagementTest);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    [Scope('OnPrem')]
    procedure TestCodeunitRunNoUserProperty()
    var
        User: Record User;
        UserProperty: Record "User Property";
        AzureADPlanTestLibrary: Codeunit "Azure AD Plan Test Library";
        AzureADPlan: Codeunit "Azure AD Plan";
        AzureADUserManagementTest: Codeunit "Azure AD User Management Test";
        UserLoginTestLibrary: Codeunit "User Login Test Library";
        UserId: Guid;
        PlanId: Guid;
    begin
        // [SCENARIO] Codeunit AzureADUserManagement exits immediately if the User 
        // Property for the user does not exist 

        Initialize(AzureADUserManagementTest);
        AzureADPlanTestLibrary.DeleteAllUserPlan();

        // [GIVEN] Running in SaaS
        EnvironmentInfo.SetTestabilitySoftwareAsAService(true);

        // [GIVEN] The User Property and User Plan tables are empty      
        UserProperty.DeleteAll();
        AzureADPlanTestLibrary.DeleteAllUserPlan();

        // [GIVEN] The Azure AD Graph contains a user 
        UserId := CreateGuid();
        AzureADUserManagementTest.AddGraphUser(UserId);

        // [GIVEN] There is a User Plan entry corresponding to the user, 
        // but the plan is not assigned to the user in the Azure AD Graph     
        PlanId := CreateGuid();
        AzureADPlanTestLibrary.AssignUserToPlan(UserId, PlanId);

        // [GIVEN] The user record's state is disabled
        DisableUserAccount(UserId);

        // [GIVEN] It is the first time that the test user logs in
        UserLoginTestLibrary.DeleteAllLoginInformation(UserId);

        // [WHEN] Running Azure AD User Management on the user
        AzureADUserManagementTest.RunAzureADUserManagement(UserId);

        // [THEN] The user record is not updated
        User.Get(UserId);
        LibraryAssert.AreEqual(User.State::Disabled, User.State,
            'The User record should not have not been updated');

        // [THEN] The User Plan that exists in the database, but not in the Azure AD Graph is not deleted
        LibraryAssert.AreEqual(true, AzureADPlan.IsPlanAssignedToUser(PlanId, UserId),
            'The User Plan table should contain the unassigned user plan');

        UnbindSubscription(AzureADUserManagementTest);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    [Scope('OnPrem')]
    procedure TestCodeunitRunUserNotFirstLogin()
    var
        UserProperty: Record "User Property";
        AzureADPlanTestLibrary: Codeunit "Azure AD Plan Test Library";
        AzureADPlan: Codeunit "Azure AD Plan";
        UserLoginTestLibrary: Codeunit "User Login Test Library";
        CompanyTriggers: Codeunit "Company Triggers";
        AzureADUserManagementTest: Codeunit "Azure AD User Management Test";
        PlanId: Guid;
    begin
        // [SCENARIO] Codeunit AzureADUserManagement exits immediately if the user has logged in before

        UserLoginTestLibrary.DeleteAllLoginInformation(UserSecurityId());

        // [GIVEN] Running in SaaS
        EnvironmentInfo.SetTestabilitySoftwareAsAService(true);
        Initialize(AzureADUserManagementTest);

        // [GIVEN] The User Property and User Plan tables are empty      
        UserProperty.DeleteAll();
        AzureADPlanTestLibrary.DeleteAllUserPlan();

        // [GIVEN] The Azure AD Graph contains a user 
        AzureADUserManagementTest.AddGraphUser(UserSecurityId());

        // [GIVEN] There is a User Plan entry corresponding to the user, 
        // but the plan is not assigned to the user in the Azure AD Graph        
        AzureADPlanTestLibrary.AssignUserToPlan(UserSecurityId(), PlanId);

        // [GIVEN] There is an entry in the User Property table for the test user 
        // [GIVEN] The User Authentication Object Id for the test user is not empty  
        UserProperty.Init();
        UserProperty."User Security ID" := UserSecurityId();
        UserProperty."Authentication Object ID" := UserSecurityId();
        UserProperty.Insert();

        // [GIVEN] It is not the first time that the test user logs in
        UserLoginTestLibrary.InsertUserLogin(UserSecurityId(), 0D, CurrentDateTime(), 0DT);

        // [WHEN] Running Azure AD User Management on the user
        AzureADUserManagementTest.RunAzureADUserManagement(UserSecurityId());

        // [THEN] The User Plan that exists in the database, but not in the Azure AD Graph is not deleted
        LibraryAssert.AreEqual(true, AzureADPlan.IsPlanAssignedToUser(PlanId, UserSecurityId()),
            'The User Plan table should contain the unassigned user plan');

        UnbindSubscription(AzureADUserManagementTest);
    end;

    [Test]
    [TransactionModel(TransactionModel::AutoRollback)]
    [Scope('OnPrem')]
    procedure TestCodeunitRunUserHasNoUserAuthenticationId()
    var
        User: Record User;
        UserProperty: Record "User Property";
        AzureADPlanTestLibrary: Codeunit "Azure AD Plan Test Library";
        AzureADPlan: Codeunit "Azure AD Plan";
        AzureADUserManagementTest: Codeunit "Azure AD User Management Test";
        UserLoginTestLibrary: Codeunit "User Login Test Library";
        UserId: Guid;
        PlanId: Guid;
    begin
        // [SCENARIO] Codeunit AzureADUserManagement exits immediately if the user has no graph authentication ID

        // [GIVEN] Running in SaaS
        EnvironmentInfo.SetTestabilitySoftwareAsAService(true);
        Initialize(AzureADUserManagementTest);

        // [GIVEN] The User Property and User Plan tables are empty      
        UserProperty.DeleteAll();
        AzureADPlanTestLibrary.DeleteAllUserPlan();

        // [GIVEN] The Azure AD Graph contains a user 
        UserId := CreateGuid();
        AzureADUserManagementTest.AddGraphUser(UserId);

        // [GIVEN] There is a User Plan entry corresponding to the user, 
        // but the plan is not assigned to the user in the Azure AD Graph     
        PlanId := CreateGuid();
        AzureADPlanTestLibrary.AssignUserToPlan(UserId, PlanId);

        // [GIVEN] The user record's state is disabled
        DisableUserAccount(UserId);

        // [GIVEN] There is an entry in the User Property table for the test user 
        // [GIVEN] The User Authentication Object Id for the test user is empty  
        UserProperty.Get(UserId);
        UserProperty."Authentication Object ID" := '';
        UserProperty.Modify();

        // [GIVEN] It is the first time that the test user logs in
        UserLoginTestLibrary.DeleteAllLoginInformation(UserId);

        // [WHEN] Running Azure AD User Management on the user
        AzureADUserManagementTest.RunAzureADUserManagement(UserId);

        // [THEN] The user record is not updated
        User.Get(UserId);
        LibraryAssert.AreEqual(User.State::Disabled, User.State,
            'The User record should not have not been updated');

        // [THEN] The User Plan that exists in the database, but not in the Azure AD Graph is not deleted
        LibraryAssert.AreEqual(true, AzureADPlan.IsPlanAssignedToUser(PlanId, UserId),
            'The User Plan table should contain the unassigned user plan');

        UnbindSubscription(AzureADUserManagementTest);
    end;

    [Test]
    [Scope('OnPrem')]
    procedure TestCodeunitRunPlansAreRefreshed()
    var
        User: Record User;
        UserProperty: Record "User Property";
        AzureADUserManagementTest: Codeunit "Azure AD User Management Test";
        AzureADPlanTestLibrary: Codeunit "Azure AD Plan Test Library";
        AzureADPlan: Codeunit "Azure AD Plan";
        UserLoginTestLibrary: Codeunit "User Login Test Library";
        AssignedPlans: DotNet IEnumerable;
        Plan: DotNet ServicePlanInfo;
        UserId: Guid;
        AssignedUserPlanId: Guid;
        UnassignedUserPlanRecordId: Guid;
        UnassignedUserPlanId: Guid;
        PlanFound: Boolean;
    begin
        Initialize(AzureADUserManagementTest);

        AssignedUserPlanId := CreateGuid();
        UnassignedUserPlanRecordId := CreateGuid();
        UnassignedUserPlanId := CreateGuid();

        // [GIVEN] The User Property and User Plan tables are empty      
        UserProperty.DeleteAll();
        AzureADPlanTestLibrary.DeleteAllUserPlan();

        // [GIVEN] Running in SaaS
        EnvironmentInfo.SetTestabilitySoftwareAsAService(true);

        // [GIVEN] The Azure AD Graph contains a user 
        UserId := CreateGuid();
        AzureADUserManagementTest.AddGraphUser(UserId);

        // [GIVEN] There is a User Plan entry corresponding to the user, 
        // but the plan is not assigned to the user in the Azure AD Graph        
        AzureADPlanTestLibrary.AssignUserToPlan(UserId, UnassignedUserPlanRecordId);

        // [GIVEN] Both the Azure AD Graph and the database contain a User Plan for the user
        AzureADUserManagementTest.AddGraphUserPlan(UserId, AssignedUserPlanId, '', 'Enabled');
        AzureADPlanTestLibrary.AssignUserToPlan(UserId, AssignedUserPlanId);

        // [GIVEN] The Azure AD Graph contains a User Plan that the database does not
        AzureADUserManagementTest.AddGraphUserPlan(UserId, UnassignedUserPlanId, '', 'Enabled');

        // [GIVEN] The user record's state is disabled
        DisableUserAccount(UserId);

        // [GIVEN] There is an entry in the User Property table for the test user 
        // [GIVEN] The User Authentication Object Id for the test user is not empty  
        UserProperty.Get(UserId);
        UserProperty."Authentication Object ID" := UserId;
        UserProperty.Modify();

        // [GIVEN] It is the first time that the test user logs in
        UserLoginTestLibrary.DeleteAllLoginInformation(UserId);

        // [WHEN] Running Azure AD User Management on the user
        AzureADUserManagementTest.RunAzureADUserManagement(UserId);

        // [THEN] The user record is updated
        User.Get(UserId);
        LibraryAssert.AreEqual(User.State::Enabled, User.State, 'The User record should have been updated');

        // [THEN] The User Plan that exists in the database, but not in the Azure AD Graph is deleted
        LibraryAssert.AreEqual(false, AzureADPlan.IsPlanAssignedToUser(UnassignedUserPlanRecordId, UserId),
            'The User Plan table should not contain the unassigned user plan');

        // [THEN] The User Plan that exists both in the database and the Azure AD Graph remains in both
        LibraryAssert.AreEqual(true, AzureADPlan.IsPlanAssigned(AssignedUserPlanId),
            'The User Plan table should contain the assigned user plan');

        AzureADUserManagementTest.GetGraphUserAssignedPlans(AssignedPlans, UserId);
        foreach Plan in AssignedPlans do
            if Plan.ServicePlanId() = AssignedUserPlanId then
                PlanFound := true;

        LibraryAssert.IsTrue(PlanFound, 'The plan should still be assigned to the user');

        // [THEN] A new entry should be inserted in the User Plan table for the plan that is assigned to 
        // the user in the Azure AD Graph
        LibraryAssert.AreEqual(true, AzureADPlan.IsPlanAssigned(UnassignedUserPlanId),
            'There should be an entry corresponding to the unassigned plan in the User Plan table');

        UnbindSubscription(AzureADUserManagementTest);
    end;


    local procedure Initialize(AzureADUserManagementTest: Codeunit "Azure AD User Management Test")
    begin
        Clear(AzureADUserManagementImpl);
        AzureADUserManagementTest.SetupMockGraphQuery();
        BindSubscription(AzureADUserManagementTest);
    end;

    procedure SetupMockGraphQuery()
    begin
        MockGraphQuery := MockGraphQuery.MockGraphQuery();
    end;

    local procedure InsertUserProperty(UserSecurityId: Guid)
    var
        UserProperty: Record "User Property";
    begin
        UserProperty.Init();
        UserProperty."User Security ID" := UserSecurityId;
        UserProperty."Authentication Object ID" := UserSecurityId;
        UserProperty.Insert();
    end;

    procedure AddGraphUser(UserId: Text)
    var
        GraphUser: DotNet UserInfo;
    begin
        CreateGraphUser(GraphUser, UserId);
        MockGraphQuery.AddUser(GraphUser);
    end;

    local procedure CreateGraphUser(var GraphUser: DotNet UserInfo; UserId: Text)
    begin
        GraphUser := GraphUser.UserInfo();
        GraphUser.ObjectId := UserId;
        GraphUser.UserPrincipalName := 'email@microsoft.com';
        GraphUser.Mail := 'email@microsoft.com';
        GraphUser.AccountEnabled := true;
    end;

    procedure AddGraphUserPlan(UserId: Text; AssignedPlanId: Guid; AssignedPlanService: Text; CapabilityStatus: Text)
    var
        GraphUser: DotNet UserInfo;
        AssignedPlan: DotNet ServicePlanInfo;
        GuidVar: Variant;
    begin
        AssignedPlan := AssignedPlan.ServicePlanInfo();
        GuidVar := AssignedPlanId;
        AssignedPlan.ServicePlanId := GuidVar;
        AssignedPlan.ServicePlanName := AssignedPlanService;
        AssignedPlan.CapabilityStatus := CapabilityStatus;

        GraphUser := MockGraphQuery.GetUserByObjectId(UserId);
        MockGraphQuery.AddAssignedPlanToUser(GraphUser, AssignedPlan);
    end;

    local procedure DisableUserAccount(UserSecurityId: Guid)
    var
        User: Record User;
    begin
        User.Init();
        User."User Security ID" := UserSecurityId;
        User.State := User.State::Disabled;
        User.Insert();
    end;

    procedure RunAzureADUserManagement(UserId: Guid)
    begin
        AzureADUserManagementImpl.SetTestInProgress(true);
        AzureADUserManagementImpl.Run(UserId);
    end;

    procedure GetGraphUserAssignedPlans(var AssignedPlans: DotNet IEnumerable; UserId: Guid)
    var
        GraphUser: DotNet UserInfo;
    begin
        AzureADGraphUser.SetTestInProgress(true);
        AzureADGraphUser.GetGraphUser(UserId, GraphUser);
        AssignedPlans := GraphUser.AssignedPlans();
    end;

    [EventSubscriber(ObjectType::Codeunit, 9012, 'OnInitialize', '', false, false)]
    local procedure OnGraphInitialization(var GraphQuery: DotNet GraphQuery)
    begin
        GraphQuery := GraphQuery.GraphQuery(MockGraphQuery);
    end;
}

