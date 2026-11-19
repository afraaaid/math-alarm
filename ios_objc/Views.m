#import "Views.h"
#import <QuartzCore/QuartzCore.h>

static UIColor *SVOrangeColor(void) {
    return [UIColor colorWithRed:1.0 green:0.45 blue:0.18 alpha:1.0];
}

static UIColor *SVGreenColor(void) {
    return [UIColor colorWithRed:0.22 green:0.88 blue:0.50 alpha:1.0];
}

static UIColor *SVCardBgColor(void) {
    return [UIColor colorWithRed:0.08 green:0.09 blue:0.11 alpha:1.0];
}

static void SVStyleDarkNavBar(UINavigationBar *navBar) {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = [UIColor blackColor];
    appearance.titleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    appearance.largeTitleTextAttributes = @{NSForegroundColorAttributeName: [UIColor whiteColor]};
    navBar.standardAppearance = appearance;
    navBar.scrollEdgeAppearance = appearance;
    navBar.compactAppearance = appearance;
    navBar.tintColor = SVOrangeColor();
    navBar.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
}

static UIView *SVMakeCardView(CGFloat radius, UIColor *bgColor, UIColor *borderColor) {
    UIView *v = [[UIView alloc] init];
    v.translatesAutoresizingMaskIntoConstraints = NO;
    v.backgroundColor = bgColor;
    v.layer.cornerRadius = radius;
    v.layer.borderWidth = 1.0;
    v.layer.borderColor = borderColor.CGColor;
    if (@available(iOS 13.0, *)) {
        v.layer.cornerCurve = kCACornerCurveContinuous;
    }
    return v;
}

#pragma mark - SVAlarmCardCell

@interface SVAlarmCardCell : UITableViewCell

@property (nonatomic, strong) UIView *cardView;
@property (nonatomic, strong) UILabel *timeLabel;
@property (nonatomic, strong) UILabel *subtitleLabel;
@property (nonatomic, strong) UISwitch *enableSwitch;
@property (nonatomic, strong) UILabel *difficultyBadge;
@property (nonatomic, strong) UILabel *volumeBadge;
@property (nonatomic, strong) UIButton *testButton;

@property (nonatomic, copy, nullable) void (^onToggle)(BOOL isOn);
@property (nonatomic, copy, nullable) void (^onTest)(void);

- (void)configureWithAlarm:(SVAlarmItem *)alarm;

@end

@implementation SVAlarmCardCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.contentView.backgroundColor = [UIColor blackColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self buildUI];
    }
    return self;
}

- (void)buildUI {
    self.cardView = SVMakeCardView(22.0, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.08]);
    [self.contentView addSubview:self.cardView];

    self.timeLabel = [[UILabel alloc] init];
    self.timeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.timeLabel.font = [UIFont monospacedDigitSystemFontOfSize:42 weight:UIFontWeightBold];
    self.timeLabel.textColor = [UIColor whiteColor];

    self.subtitleLabel = [[UILabel alloc] init];
    self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.subtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];

    self.enableSwitch = [[UISwitch alloc] init];
    self.enableSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    self.enableSwitch.onTintColor = SVOrangeColor();
    [self.enableSwitch addTarget:self action:@selector(switchChanged:) forControlEvents:UIControlEventValueChanged];

    UIView *divider = [[UIView alloc] init];
    divider.translatesAutoresizingMaskIntoConstraints = NO;
    divider.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];

    self.difficultyBadge = [[UILabel alloc] init];
    self.difficultyBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.difficultyBadge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.difficultyBadge.layer.cornerRadius = 11.0;
    self.difficultyBadge.clipsToBounds = YES;

    self.volumeBadge = [[UILabel alloc] init];
    self.volumeBadge.translatesAutoresizingMaskIntoConstraints = NO;
    self.volumeBadge.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    self.volumeBadge.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];
    self.volumeBadge.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.volumeBadge.layer.cornerRadius = 11.0;
    self.volumeBadge.clipsToBounds = YES;

    self.testButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.testButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.testButton setTitle:@"  ▶ Test  " forState:UIControlStateNormal];
    self.testButton.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    [self.testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.testButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.13];
    self.testButton.layer.cornerRadius = 13.0;
    [self.testButton addTarget:self action:@selector(testTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.cardView addSubview:self.timeLabel];
    [self.cardView addSubview:self.subtitleLabel];
    [self.cardView addSubview:self.enableSwitch];
    [self.cardView addSubview:divider];
    [self.cardView addSubview:self.difficultyBadge];
    [self.cardView addSubview:self.volumeBadge];
    [self.cardView addSubview:self.testButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.cardView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:6],
        [self.cardView.bottomAnchor constraintEqualToAnchor:self.contentView.bottomAnchor constant:-6],
        [self.cardView.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor constant:16],
        [self.cardView.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor constant:-16],

        [self.timeLabel.topAnchor constraintEqualToAnchor:self.cardView.topAnchor constant:14],
        [self.timeLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],

        [self.enableSwitch.centerYAnchor constraintEqualToAnchor:self.timeLabel.centerYAnchor constant:6],
        [self.enableSwitch.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],

        [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.timeLabel.bottomAnchor constant:2],
        [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.subtitleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.enableSwitch.leadingAnchor constant:-12],

        [divider.topAnchor constraintEqualToAnchor:self.subtitleLabel.bottomAnchor constant:12],
        [divider.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [divider.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],
        [divider.heightAnchor constraintEqualToConstant:1],

        [self.difficultyBadge.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:10],
        [self.difficultyBadge.leadingAnchor constraintEqualToAnchor:self.cardView.leadingAnchor constant:16],
        [self.difficultyBadge.heightAnchor constraintEqualToConstant:24],
        [self.difficultyBadge.bottomAnchor constraintEqualToAnchor:self.cardView.bottomAnchor constant:-14],

        [self.volumeBadge.centerYAnchor constraintEqualToAnchor:self.difficultyBadge.centerYAnchor],
        [self.volumeBadge.leadingAnchor constraintEqualToAnchor:self.difficultyBadge.trailingAnchor constant:8],
        [self.volumeBadge.heightAnchor constraintEqualToConstant:24],

        [self.testButton.centerYAnchor constraintEqualToAnchor:self.difficultyBadge.centerYAnchor],
        [self.testButton.trailingAnchor constraintEqualToAnchor:self.cardView.trailingAnchor constant:-16],
        [self.testButton.heightAnchor constraintEqualToConstant:28]
    ]];
}

- (void)configureWithAlarm:(SVAlarmItem *)alarm {
    self.timeLabel.text = alarm.formattedTime;
    self.subtitleLabel.text = [NSString stringWithFormat:@"%@ • %@", alarm.label, alarm.repeatSummary];
    self.enableSwitch.on = alarm.enabled;

    if (alarm.enabled) {
        self.cardView.backgroundColor = [UIColor colorWithRed:0.09 green:0.10 blue:0.12 alpha:1.0];
        self.cardView.layer.borderColor = [SVOrangeColor() colorWithAlphaComponent:0.35].CGColor;
        self.timeLabel.textColor = [UIColor whiteColor];
        self.subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    } else {
        self.cardView.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.06 alpha:1.0];
        self.cardView.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.07].CGColor;
        self.timeLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.42];
        self.subtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.38];
    }

    UIColor *diffColor = SVMathDifficultyColor(alarm.difficulty);
    self.difficultyBadge.text = [NSString stringWithFormat:@"  %@ ×%ld  ", SVMathDifficultyTitle(alarm.difficulty), (long)alarm.problemCount];
    self.difficultyBadge.textColor = diffColor;
    self.difficultyBadge.backgroundColor = [diffColor colorWithAlphaComponent:0.18];

    if (alarm.lockVolume) {
        self.volumeBadge.hidden = NO;
        self.volumeBadge.text = @"  🔊 Vol 100%  ";
    } else {
        self.volumeBadge.hidden = YES;
    }
}

- (void)switchChanged:(UISwitch *)sender {
    if (self.onToggle) {
        self.onToggle(sender.isOn);
    }
}

- (void)testTapped {
    if (self.onTest) {
        self.onTest();
    }
}

@end

#pragma mark - SVAlarmListViewController

@interface SVAlarmListViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIStackView *headerStack;
@property (nonatomic, strong) UILabel *nextAlarmTitleLabel;
@property (nonatomic, strong) UILabel *nextAlarmSubtitleLabel;
@property (nonatomic, strong) UIView *wakeUpCard;
@property (nonatomic, strong) UILabel *wakeUpCountdownLabel;
@property (nonatomic, strong) UIView *permissionsCard;
@property (nonatomic, strong) UIView *emptyStateView;
@property (nonatomic, strong) NSTimer *refreshTimer;

@end

@implementation SVAlarmListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"Sveglia";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    SVStyleDarkNavBar(self.navigationController.navigationBar);

    UIBarButtonItem *addItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                             target:self
                                                                             action:@selector(addAlarmTapped)];
    addItem.tintColor = SVOrangeColor();
    self.navigationItem.rightBarButtonItem = addItem;

    [self setupTableAndHeader];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadAllUI)
                                                 name:SVAlarmEngineDidChangeStateNotification
                                               object:nil];

    __weak typeof(self) weakSelf = self;
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateHeaderDynamicLabels];
    }];

    [self reloadAllUI];
}

- (void)dealloc {
    [self.refreshTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self sizeTableHeaderToFit];
}

- (void)setupTableAndHeader {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor blackColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerClass:[SVAlarmCardCell class] forCellReuseIdentifier:@"AlarmCell"];
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];

    UIView *headerContainer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width ?: 390, 200)];
    headerContainer.backgroundColor = [UIColor blackColor];

    self.headerStack = [[UIStackView alloc] init];
    self.headerStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.headerStack.axis = UILayoutConstraintAxisVertical;
    self.headerStack.spacing = 12;
    [headerContainer addSubview:self.headerStack];

    [NSLayoutConstraint activateConstraints:@[
        [self.headerStack.topAnchor constraintEqualToAnchor:headerContainer.topAnchor constant:8],
        [self.headerStack.bottomAnchor constraintEqualToAnchor:headerContainer.bottomAnchor constant:-10],
        [self.headerStack.leadingAnchor constraintEqualToAnchor:headerContainer.leadingAnchor constant:16],
        [self.headerStack.trailingAnchor constraintEqualToAnchor:headerContainer.trailingAnchor constant:-16]
    ]];

    // Status Card
    UIView *statusCard = SVMakeCardView(20.0, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.10]);
    UILabel *badge = [[UILabel alloc] init];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.text = @"⚡ 0% BATTERIA NOTTURNA • ANTI-CHIUSURA";
    badge.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    badge.textColor = SVGreenColor();

    self.nextAlarmTitleLabel = [[UILabel alloc] init];
    self.nextAlarmTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nextAlarmTitleLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
    self.nextAlarmTitleLabel.textColor = [UIColor whiteColor];
    self.nextAlarmTitleLabel.numberOfLines = 0;

    self.nextAlarmSubtitleLabel = [[UILabel alloc] init];
    self.nextAlarmSubtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.nextAlarmSubtitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightRegular];
    self.nextAlarmSubtitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    self.nextAlarmSubtitleLabel.numberOfLines = 0;

    [statusCard addSubview:badge];
    [statusCard addSubview:self.nextAlarmTitleLabel];
    [statusCard addSubview:self.nextAlarmSubtitleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [badge.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:14],
        [badge.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:16],
        [badge.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-16],
        [self.nextAlarmTitleLabel.topAnchor constraintEqualToAnchor:badge.bottomAnchor constant:8],
        [self.nextAlarmTitleLabel.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:16],
        [self.nextAlarmTitleLabel.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-16],
        [self.nextAlarmSubtitleLabel.topAnchor constraintEqualToAnchor:self.nextAlarmTitleLabel.bottomAnchor constant:4],
        [self.nextAlarmSubtitleLabel.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:16],
        [self.nextAlarmSubtitleLabel.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-16],
        [self.nextAlarmSubtitleLabel.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-14]
    ]];
    [self.headerStack addArrangedSubview:statusCard];

    // WakeUp Check Card
    self.wakeUpCard = SVMakeCardView(20.0,
                                     [UIColor colorWithRed:0.16 green:0.13 blue:0.04 alpha:1.0],
                                     [[UIColor systemYellowColor] colorWithAlphaComponent:0.45]);
    UILabel *wakeTitle = [[UILabel alloc] init];
    wakeTitle.translatesAutoresizingMaskIntoConstraints = NO;
    wakeTitle.text = @"👀 Controllo Sveglio in corso";
    wakeTitle.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    wakeTitle.textColor = [UIColor whiteColor];

    self.wakeUpCountdownLabel = [[UILabel alloc] init];
    self.wakeUpCountdownLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.wakeUpCountdownLabel.font = [UIFont monospacedDigitSystemFontOfSize:15 weight:UIFontWeightBold];
    self.wakeUpCountdownLabel.textColor = [UIColor systemYellowColor];

    UILabel *wakeBody = [[UILabel alloc] init];
    wakeBody.translatesAutoresizingMaskIntoConstraints = NO;
    wakeBody.text = @"Conferma di essere sveglio prima dello scadere del timer, altrimenti la sirena ripartirà!";
    wakeBody.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    wakeBody.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];
    wakeBody.numberOfLines = 0;

    UIButton *confirmWakeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    confirmWakeBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [confirmWakeBtn setTitle:@"Conferma: Sono Sveglio" forState:UIControlStateNormal];
    confirmWakeBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [confirmWakeBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    confirmWakeBtn.backgroundColor = SVGreenColor();
    confirmWakeBtn.layer.cornerRadius = 12.0;
    [confirmWakeBtn addTarget:self action:@selector(confirmWakeUpTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.wakeUpCard addSubview:wakeTitle];
    [self.wakeUpCard addSubview:self.wakeUpCountdownLabel];
    [self.wakeUpCard addSubview:wakeBody];
    [self.wakeUpCard addSubview:confirmWakeBtn];
    [NSLayoutConstraint activateConstraints:@[
        [wakeTitle.topAnchor constraintEqualToAnchor:self.wakeUpCard.topAnchor constant:14],
        [wakeTitle.leadingAnchor constraintEqualToAnchor:self.wakeUpCard.leadingAnchor constant:16],
        [self.wakeUpCountdownLabel.centerYAnchor constraintEqualToAnchor:wakeTitle.centerYAnchor],
        [self.wakeUpCountdownLabel.trailingAnchor constraintEqualToAnchor:self.wakeUpCard.trailingAnchor constant:-16],
        [wakeBody.topAnchor constraintEqualToAnchor:wakeTitle.bottomAnchor constant:6],
        [wakeBody.leadingAnchor constraintEqualToAnchor:self.wakeUpCard.leadingAnchor constant:16],
        [wakeBody.trailingAnchor constraintEqualToAnchor:self.wakeUpCard.trailingAnchor constant:-16],
        [confirmWakeBtn.topAnchor constraintEqualToAnchor:wakeBody.bottomAnchor constant:12],
        [confirmWakeBtn.leadingAnchor constraintEqualToAnchor:self.wakeUpCard.leadingAnchor constant:16],
        [confirmWakeBtn.trailingAnchor constraintEqualToAnchor:self.wakeUpCard.trailingAnchor constant:-16],
        [confirmWakeBtn.heightAnchor constraintEqualToConstant:44],
        [confirmWakeBtn.bottomAnchor constraintEqualToAnchor:self.wakeUpCard.bottomAnchor constant:-14]
    ]];
    [self.headerStack addArrangedSubview:self.wakeUpCard];

    // Permissions Card
    self.permissionsCard = SVMakeCardView(20.0,
                                          [UIColor colorWithRed:0.14 green:0.08 blue:0.05 alpha:1.0],
                                          [SVOrangeColor() colorWithAlphaComponent:0.45]);
    UILabel *permTitle = [[UILabel alloc] init];
    permTitle.translatesAutoresizingMaskIntoConstraints = NO;
    permTitle.text = @"🔔 Permessi richiesti per suonare";
    permTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    permTitle.textColor = [UIColor whiteColor];

    UILabel *permBody = [[UILabel alloc] init];
    permBody.translatesAutoresizingMaskIntoConstraints = NO;
    permBody.text = @"Abilita Notifiche Time-Sensitive affinché la catena di sveglie suoni anche ad app chiusa.";
    permBody.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    permBody.textColor = [UIColor colorWithWhite:1.0 alpha:0.72];
    permBody.numberOfLines = 0;

    UIButton *permBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    permBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [permBtn setTitle:@"Attiva Permessi Ora" forState:UIControlStateNormal];
    permBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [permBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    permBtn.backgroundColor = SVOrangeColor();
    permBtn.layer.cornerRadius = 12.0;
    [permBtn addTarget:self action:@selector(requestPermissionsTapped) forControlEvents:UIControlEventTouchUpInside];

    [self.permissionsCard addSubview:permTitle];
    [self.permissionsCard addSubview:permBody];
    [self.permissionsCard addSubview:permBtn];
    [NSLayoutConstraint activateConstraints:@[
        [permTitle.topAnchor constraintEqualToAnchor:self.permissionsCard.topAnchor constant:14],
        [permTitle.leadingAnchor constraintEqualToAnchor:self.permissionsCard.leadingAnchor constant:16],
        [permTitle.trailingAnchor constraintEqualToAnchor:self.permissionsCard.trailingAnchor constant:-16],
        [permBody.topAnchor constraintEqualToAnchor:permTitle.bottomAnchor constant:6],
        [permBody.leadingAnchor constraintEqualToAnchor:self.permissionsCard.leadingAnchor constant:16],
        [permBody.trailingAnchor constraintEqualToAnchor:self.permissionsCard.trailingAnchor constant:-16],
        [permBtn.topAnchor constraintEqualToAnchor:permBody.bottomAnchor constant:12],
        [permBtn.leadingAnchor constraintEqualToAnchor:self.permissionsCard.leadingAnchor constant:16],
        [permBtn.trailingAnchor constraintEqualToAnchor:self.permissionsCard.trailingAnchor constant:-16],
        [permBtn.heightAnchor constraintEqualToConstant:42],
        [permBtn.bottomAnchor constraintEqualToAnchor:self.permissionsCard.bottomAnchor constant:-14]
    ]];
    [self.headerStack addArrangedSubview:self.permissionsCard];

    self.tableView.tableHeaderView = headerContainer;

    // Empty state footer
    self.emptyStateView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 140)];
    UILabel *emptyLabel = [[UILabel alloc] init];
    emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    emptyLabel.text = @"Nessuna sveglia impostata.\nTocca + in alto a destra per crearne una.";
    emptyLabel.numberOfLines = 0;
    emptyLabel.textAlignment = NSTextAlignmentCenter;
    emptyLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    emptyLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];
    [self.emptyStateView addSubview:emptyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [emptyLabel.centerXAnchor constraintEqualToAnchor:self.emptyStateView.centerXAnchor],
        [emptyLabel.centerYAnchor constraintEqualToAnchor:self.emptyStateView.centerYAnchor],
        [emptyLabel.leadingAnchor constraintEqualToAnchor:self.emptyStateView.leadingAnchor constant:24],
        [emptyLabel.trailingAnchor constraintEqualToAnchor:self.emptyStateView.trailingAnchor constant:-24]
    ]];
}

- (void)sizeTableHeaderToFit {
    UIView *header = self.tableView.tableHeaderView;
    if (!header) {
        return;
    }
    CGFloat width = self.tableView.bounds.size.width;
    if (width <= 0) {
        return;
    }
    CGSize target = [header systemLayoutSizeFittingSize:CGSizeMake(width, UILayoutFittingCompressedSize.height)
                          withHorizontalFittingPriority:UILayoutPriorityRequired
                                verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    if (fabs(header.frame.size.height - target.height) > 1.0) {
        CGRect f = header.frame;
        f.size.height = target.height;
        f.size.width = width;
        header.frame = f;
        self.tableView.tableHeaderView = header;
    }
}

- (void)reloadAllUI {
    SVAlarmEngine *engine = [SVAlarmEngine shared];
    self.wakeUpCard.hidden = (engine.wakeUpCheckPendingUntil == nil);
    self.permissionsCard.hidden = (engine.notificationStatus == UNAuthorizationStatusAuthorized);
    self.tableView.tableFooterView = (engine.alarms.count == 0) ? self.emptyStateView : [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 24)];
    [self updateHeaderDynamicLabels];
    [self sizeTableHeaderToFit];
    [self.tableView reloadData];
}

- (void)updateHeaderDynamicLabels {
    SVAlarmEngine *engine = [SVAlarmEngine shared];
    NSDate *nextDate = nil;
    SVAlarmItem *nextAlarm = [engine nextScheduledAlarmWithDate:&nextDate];
    if (nextAlarm && nextDate) {
        self.nextAlarmTitleLabel.text = [NSString stringWithFormat:@"Prossima sveglia alle %@", nextAlarm.formattedTime];
        NSTimeInterval diff = MAX(0, [nextDate timeIntervalSinceNow]);
        NSInteger totalSec = (NSInteger)diff;
        NSInteger days = totalSec / 86400;
        NSInteger hours = (totalSec % 86400) / 3600;
        NSInteger mins = (totalSec % 3600) / 60;
        NSString *countdown = (days > 0)
            ? [NSString stringWithFormat:@"tra %ldg %ldh", (long)days, (long)hours]
            : (hours > 0 ? [NSString stringWithFormat:@"tra %ldh %ldm", (long)hours, (long)mins]
                         : [NSString stringWithFormat:@"tra %ld min", (long)MAX(1, mins)]);
        self.nextAlarmSubtitleLabel.text = [NSString stringWithFormat:@"%@ • %@", nextAlarm.label, countdown];
    } else {
        self.nextAlarmTitleLabel.text = @"Nessuna sveglia attiva";
        self.nextAlarmSubtitleLabel.text = @"Attiva una sveglia o premi Test per provare il blocco matematico.";
    }

    if (engine.wakeUpCheckPendingUntil) {
        NSInteger rem = MAX(0, (NSInteger)[engine.wakeUpCheckPendingUntil timeIntervalSinceNow]);
        self.wakeUpCountdownLabel.text = [NSString stringWithFormat:@"%02ld:%02ld", (long)(rem / 60), (long)(rem % 60)];
    }
}

- (void)addAlarmTapped {
    SVAlarmEditorViewController *editor = [[SVAlarmEditorViewController alloc] initWithAlarm:nil onSave:^(SVAlarmItem *saved) {
        [[SVAlarmEngine shared] upsertAlarm:saved];
    } onDelete:nil];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
    SVStyleDarkNavBar(nav.navigationBar);
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)confirmWakeUpTapped {
    [[SVAlarmEngine shared] confirmWakeUpCheck];
}

- (void)requestPermissionsTapped {
    [[SVAlarmEngine shared] requestPermissionsWithCompletion:nil];
}

#pragma mark - UITableViewDataSource & Delegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)[SVAlarmEngine shared].alarms.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SVAlarmCardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"AlarmCell" forIndexPath:indexPath];
    SVAlarmItem *alarm = [SVAlarmEngine shared].alarms[(NSUInteger)indexPath.row];
    [cell configureWithAlarm:alarm];

    NSString *alarmID = alarm.alarmID;
    cell.onToggle = ^(BOOL isOn) {
        [[SVAlarmEngine shared] toggleAlarmID:alarmID enabled:isOn];
    };
    cell.onTest = ^{
        [[SVAlarmEngine shared] triggerTestAlarm:alarm];
    };
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SVAlarmItem *alarm = [SVAlarmEngine shared].alarms[(NSUInteger)indexPath.row];
    SVAlarmEditorViewController *editor = [[SVAlarmEditorViewController alloc] initWithAlarm:alarm onSave:^(SVAlarmItem *saved) {
        [[SVAlarmEngine shared] upsertAlarm:saved];
    } onDelete:^(NSString *alarmID) {
        [[SVAlarmEngine shared] deleteAlarmID:alarmID];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:editor];
    SVStyleDarkNavBar(nav.navigationBar);
    [self presentViewController:nav animated:YES completion:nil];
}

- (UISwipeActionsConfiguration *)tableView:(UITableView *)tableView
trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath {
    SVAlarmItem *alarm = [SVAlarmEngine shared].alarms[(NSUInteger)indexPath.row];
    NSString *alarmID = alarm.alarmID;
    UIContextualAction *del = [UIContextualAction contextualActionWithStyle:UIContextualActionStyleDestructive
                                                                      title:@"Elimina"
                                                                    handler:^(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL)) {
        [[SVAlarmEngine shared] deleteAlarmID:alarmID];
        completionHandler(YES);
    }];
    return [UISwipeActionsConfiguration configurationWithActions:@[del]];
}

@end

#pragma mark - SVAlarmEditorViewController

@interface SVAlarmEditorViewController () <UITextFieldDelegate>

@property (nonatomic, assign) BOOL isEditingAlarm;
@property (nonatomic, strong) SVAlarmItem *draft;
@property (nonatomic, copy) void (^onSave)(SVAlarmItem *saved);
@property (nonatomic, copy, nullable) void (^onDelete)(NSString *alarmID);

@property (nonatomic, strong) UIDatePicker *timePicker;
@property (nonatomic, strong) UITextField *labelField;
@property (nonatomic, strong) NSMutableArray<UIButton *> *dayButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *difficultyButtons;
@property (nonatomic, strong) UILabel *previewEquationLabel;
@property (nonatomic, strong) UILabel *problemCountValueLabel;
@property (nonatomic, strong) UIStepper *problemStepper;
@property (nonatomic, strong) NSMutableArray<UIButton *> *soundSelectButtons;
@property (nonatomic, strong) NSMutableArray<UIButton *> *soundPlayButtons;

@property (nonatomic, strong) UISwitch *lockVolumeSwitch;
@property (nonatomic, strong) UISwitch *smartQuietSwitch;
@property (nonatomic, strong) UISwitch *wakeUpSwitch;
@property (nonatomic, strong) UISwitch *fadeInSwitch;

@end

@implementation SVAlarmEditorViewController

- (instancetype)initWithAlarm:(SVAlarmItem *)alarm
                       onSave:(void (^)(SVAlarmItem *))onSave
                     onDelete:(void (^)(NSString *))onDelete {
    self = [super init];
    if (self) {
        _isEditingAlarm = (alarm != nil);
        _draft = alarm ? [alarm copy] : [[SVAlarmItem alloc] initWithDefaultValues];
        if (!alarm) {
            _draft.enabled = YES;
        }
        _onSave = [onSave copy];
        _onDelete = [onDelete copy];
        _dayButtons = [NSMutableArray array];
        _difficultyButtons = [NSMutableArray array];
        _soundSelectButtons = [NSMutableArray array];
        _soundPlayButtons = [NSMutableArray array];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = self.isEditingAlarm ? @"Modifica Sveglia" : @"Nuova Sveglia";

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Annulla"
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:self
                                                                            action:@selector(cancelTapped)];
    self.navigationItem.leftBarButtonItem.tintColor = [UIColor colorWithWhite:1.0 alpha:0.75];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Salva"
                                                                              style:UIBarButtonItemStyleDone
                                                                             target:self
                                                                             action:@selector(saveTapped)];
    self.navigationItem.rightBarButtonItem.tintColor = SVOrangeColor();

    [self buildEditorUI];
    [self refreshDifficultyUI];
    [self refreshDayButtonsUI];
    [self refreshSoundUI];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshSoundUI)
                                                 name:SVAlarmEngineDidChangeStateNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[SVAudioSirenService shared] stopPreview];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildEditorUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    // 1. Time Picker Card
    UIView *pickerCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    self.timePicker = [[UIDatePicker alloc] init];
    self.timePicker.translatesAutoresizingMaskIntoConstraints = NO;
    self.timePicker.datePickerMode = UIDatePickerModeTime;
    if (@available(iOS 13.4, *)) {
        self.timePicker.preferredDatePickerStyle = UIDatePickerStyleWheels;
    }
    self.timePicker.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:(NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay) fromDate:[NSDate date]];
    comps.hour = self.draft.hour;
    comps.minute = self.draft.minute;
    NSDate *initialDate = [[NSCalendar currentCalendar] dateFromComponents:comps];
    if (initialDate) {
        self.timePicker.date = initialDate;
    }
    [pickerCard addSubview:self.timePicker];
    [NSLayoutConstraint activateConstraints:@[
        [self.timePicker.topAnchor constraintEqualToAnchor:pickerCard.topAnchor constant:4],
        [self.timePicker.bottomAnchor constraintEqualToAnchor:pickerCard.bottomAnchor constant:-4],
        [self.timePicker.centerXAnchor constraintEqualToAnchor:pickerCard.centerXAnchor],
        [self.timePicker.heightAnchor constraintEqualToConstant:180]
    ]];
    [stack addArrangedSubview:pickerCard];

    // 2. Label & Repeat Days Card
    UIView *repeatCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UIStackView *repeatStack = [[UIStackView alloc] init];
    repeatStack.translatesAutoresizingMaskIntoConstraints = NO;
    repeatStack.axis = UILayoutConstraintAxisVertical;
    repeatStack.spacing = 12;
    [repeatCard addSubview:repeatStack];
    [NSLayoutConstraint activateConstraints:@[
        [repeatStack.topAnchor constraintEqualToAnchor:repeatCard.topAnchor constant:16],
        [repeatStack.bottomAnchor constraintEqualToAnchor:repeatCard.bottomAnchor constant:-16],
        [repeatStack.leadingAnchor constraintEqualToAnchor:repeatCard.leadingAnchor constant:16],
        [repeatStack.trailingAnchor constraintEqualToAnchor:repeatCard.trailingAnchor constant:-16]
    ]];

    UILabel *lblTitle = [[UILabel alloc] init];
    lblTitle.text = @"Etichetta";
    lblTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    lblTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    [repeatStack addArrangedSubview:lblTitle];

    self.labelField = [[UITextField alloc] init];
    self.labelField.text = self.draft.label;
    self.labelField.placeholder = @"Nome sveglia";
    self.labelField.textColor = [UIColor whiteColor];
    self.labelField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.07];
    self.labelField.layer.cornerRadius = 12;
    self.labelField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 40)];
    self.labelField.leftViewMode = UITextFieldViewModeAlways;
    self.labelField.returnKeyType = UIReturnKeyDone;
    self.labelField.delegate = self;
    [self.labelField.heightAnchor constraintEqualToConstant:42].active = YES;
    [repeatStack addArrangedSubview:self.labelField];

    UILabel *repTitle = [[UILabel alloc] init];
    repTitle.text = @"Ripetizione";
    repTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
    repTitle.textColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    [repeatStack addArrangedSubview:repTitle];

    UIStackView *daysRow = [[UIStackView alloc] init];
    daysRow.distribution = UIStackViewDistributionFillEqually;
    daysRow.spacing = 8;
    NSArray<NSString *> *letters = @[@"L", @"M", @"M", @"G", @"V", @"S", @"D"];
    for (NSInteger i = 0; i < 7; i++) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = i + 1;
        [btn setTitle:letters[(NSUInteger)i] forState:UIControlStateNormal];
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        btn.layer.cornerRadius = 19;
        [btn.heightAnchor constraintEqualToConstant:38].active = YES;
        [btn addTarget:self action:@selector(dayTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.dayButtons addObject:btn];
        [daysRow addArrangedSubview:btn];
    }
    [repeatStack addArrangedSubview:daysRow];

    UIStackView *presetRow = [[UIStackView alloc] init];
    presetRow.distribution = UIStackViewDistributionFillEqually;
    presetRow.spacing = 6;
    NSArray<NSString *> *presets = @[@"Feriali", @"Weekend", @"Tutti", @"Mai"];
    for (NSInteger p = 0; p < 4; p++) {
        UIButton *pBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        pBtn.tag = p;
        [pBtn setTitle:presets[(NSUInteger)p] forState:UIControlStateNormal];
        pBtn.titleLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold];
        [pBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        pBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
        pBtn.layer.cornerRadius = 14;
        [pBtn.heightAnchor constraintEqualToConstant:30].active = YES;
        [pBtn addTarget:self action:@selector(presetTapped:) forControlEvents:UIControlEventTouchUpInside];
        [presetRow addArrangedSubview:pBtn];
    }
    [repeatStack addArrangedSubview:presetRow];
    [stack addArrangedSubview:repeatCard];

    // 3. Math Difficulty Card
    UIView *mathCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UIStackView *mathStack = [[UIStackView alloc] init];
    mathStack.translatesAutoresizingMaskIntoConstraints = NO;
    mathStack.axis = UILayoutConstraintAxisVertical;
    mathStack.spacing = 12;
    [mathCard addSubview:mathStack];
    [NSLayoutConstraint activateConstraints:@[
        [mathStack.topAnchor constraintEqualToAnchor:mathCard.topAnchor constant:16],
        [mathStack.bottomAnchor constraintEqualToAnchor:mathCard.bottomAnchor constant:-16],
        [mathStack.leadingAnchor constraintEqualToAnchor:mathCard.leadingAnchor constant:16],
        [mathStack.trailingAnchor constraintEqualToAnchor:mathCard.trailingAnchor constant:-16]
    ]];

    UILabel *mathTitle = [[UILabel alloc] init];
    mathTitle.text = @"Sfida Matematica per Spegnere";
    mathTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    mathTitle.textColor = [UIColor whiteColor];
    [mathStack addArrangedSubview:mathTitle];

    UIStackView *diffRow1 = [[UIStackView alloc] init];
    diffRow1.distribution = UIStackViewDistributionFillEqually;
    diffRow1.spacing = 10;
    UIStackView *diffRow2 = [[UIStackView alloc] init];
    diffRow2.distribution = UIStackViewDistributionFillEqually;
    diffRow2.spacing = 10;

    for (NSInteger d = 0; d < 4; d++) {
        SVMathDifficulty diff = (SVMathDifficulty)d;
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
        btn.tag = d;
        btn.titleLabel.numberOfLines = 2;
        btn.titleLabel.textAlignment = NSTextAlignmentCenter;
        btn.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightBold];
        [btn setTitle:SVMathDifficultyTitle(diff) forState:UIControlStateNormal];
        btn.layer.cornerRadius = 14;
        [btn.heightAnchor constraintEqualToConstant:48].active = YES;
        [btn addTarget:self action:@selector(difficultyTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.difficultyButtons addObject:btn];
        if (d < 2) {
            [diffRow1 addArrangedSubview:btn];
        } else {
            [diffRow2 addArrangedSubview:btn];
        }
    }
    [mathStack addArrangedSubview:diffRow1];
    [mathStack addArrangedSubview:diffRow2];

    UIView *previewBox = SVMakeCardView(12, [UIColor colorWithWhite:1.0 alpha:0.05], [UIColor clearColor]);
    self.previewEquationLabel = [[UILabel alloc] init];
    self.previewEquationLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.previewEquationLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightBold];
    self.previewEquationLabel.textColor = [UIColor whiteColor];
    self.previewEquationLabel.adjustsFontSizeToFitWidth = YES;
    self.previewEquationLabel.minimumScaleFactor = 0.6;

    UIButton *refreshPrevBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    refreshPrevBtn.translatesAutoresizingMaskIntoConstraints = NO;
    [refreshPrevBtn setTitle:@"↻" forState:UIControlStateNormal];
    refreshPrevBtn.titleLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [refreshPrevBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    refreshPrevBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    refreshPrevBtn.layer.cornerRadius = 16;
    [refreshPrevBtn addTarget:self action:@selector(refreshPreviewTapped) forControlEvents:UIControlEventTouchUpInside];

    [previewBox addSubview:self.previewEquationLabel];
    [previewBox addSubview:refreshPrevBtn];
    [NSLayoutConstraint activateConstraints:@[
        [self.previewEquationLabel.topAnchor constraintEqualToAnchor:previewBox.topAnchor constant:12],
        [self.previewEquationLabel.bottomAnchor constraintEqualToAnchor:previewBox.bottomAnchor constant:-12],
        [self.previewEquationLabel.leadingAnchor constraintEqualToAnchor:previewBox.leadingAnchor constant:12],
        [self.previewEquationLabel.trailingAnchor constraintLessThanOrEqualToAnchor:refreshPrevBtn.leadingAnchor constant:-8],
        [refreshPrevBtn.centerYAnchor constraintEqualToAnchor:previewBox.centerYAnchor],
        [refreshPrevBtn.trailingAnchor constraintEqualToAnchor:previewBox.trailingAnchor constant:-10],
        [refreshPrevBtn.widthAnchor constraintEqualToConstant:32],
        [refreshPrevBtn.heightAnchor constraintEqualToConstant:32]
    ]];
    [mathStack addArrangedSubview:previewBox];
    [self refreshPreviewTapped];

    UIStackView *stepperRow = [[UIStackView alloc] init];
    stepperRow.alignment = UIStackViewAlignmentCenter;
    stepperRow.spacing = 10;
    UILabel *cntTitle = [[UILabel alloc] init];
    cntTitle.text = @"Numero di calcoli richiesti";
    cntTitle.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    cntTitle.textColor = [UIColor whiteColor];

    self.problemCountValueLabel = [[UILabel alloc] init];
    self.problemCountValueLabel.text = [NSString stringWithFormat:@"%ld", (long)self.draft.problemCount];
    self.problemCountValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:18 weight:UIFontWeightBold];
    self.problemCountValueLabel.textColor = SVOrangeColor();

    self.problemStepper = [[UIStepper alloc] init];
    self.problemStepper.minimumValue = 1;
    self.problemStepper.maximumValue = 10;
    self.problemStepper.value = (double)self.draft.problemCount;
    [self.problemStepper addTarget:self action:@selector(stepperChanged:) forControlEvents:UIControlEventValueChanged];

    [stepperRow addArrangedSubview:cntTitle];
    [stepperRow addArrangedSubview:self.problemCountValueLabel];
    [stepperRow addArrangedSubview:self.problemStepper];
    [mathStack addArrangedSubview:stepperRow];
    [stack addArrangedSubview:mathCard];

    // 4. Sound Picker Card
    UIView *soundCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UIStackView *soundStack = [[UIStackView alloc] init];
    soundStack.translatesAutoresizingMaskIntoConstraints = NO;
    soundStack.axis = UILayoutConstraintAxisVertical;
    soundStack.spacing = 10;
    [soundCard addSubview:soundStack];
    [NSLayoutConstraint activateConstraints:@[
        [soundStack.topAnchor constraintEqualToAnchor:soundCard.topAnchor constant:16],
        [soundStack.bottomAnchor constraintEqualToAnchor:soundCard.bottomAnchor constant:-16],
        [soundStack.leadingAnchor constraintEqualToAnchor:soundCard.leadingAnchor constant:16],
        [soundStack.trailingAnchor constraintEqualToAnchor:soundCard.trailingAnchor constant:-16]
    ]];

    UILabel *soundTitle = [[UILabel alloc] init];
    soundTitle.text = @"Suoneria Sirena";
    soundTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    soundTitle.textColor = [UIColor whiteColor];
    [soundStack addArrangedSubview:soundTitle];

    for (NSInteger s = 0; s < 4; s++) {
        SVAlarmSound snd = (SVAlarmSound)s;
        UIView *row = [[UIView alloc] init];
        row.translatesAutoresizingMaskIntoConstraints = NO;
        row.layer.cornerRadius = 12;

        UIButton *selBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        selBtn.translatesAutoresizingMaskIntoConstraints = NO;
        selBtn.tag = s;
        selBtn.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        [selBtn setTitle:[NSString stringWithFormat:@"  %@", SVAlarmSoundDisplayName(snd)] forState:UIControlStateNormal];
        selBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [selBtn addTarget:self action:@selector(soundSelected:) forControlEvents:UIControlEventTouchUpInside];
        [self.soundSelectButtons addObject:selBtn];

        UIButton *playBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        playBtn.translatesAutoresizingMaskIntoConstraints = NO;
        playBtn.tag = s;
        playBtn.layer.cornerRadius = 16;
        playBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
        [playBtn addTarget:self action:@selector(soundPreviewTapped:) forControlEvents:UIControlEventTouchUpInside];
        [self.soundPlayButtons addObject:playBtn];

        [row addSubview:selBtn];
        [row addSubview:playBtn];
        [NSLayoutConstraint activateConstraints:@[
            [selBtn.topAnchor constraintEqualToAnchor:row.topAnchor constant:6],
            [selBtn.bottomAnchor constraintEqualToAnchor:row.bottomAnchor constant:-6],
            [selBtn.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:8],
            [selBtn.trailingAnchor constraintLessThanOrEqualToAnchor:playBtn.leadingAnchor constant:-8],
            [playBtn.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [playBtn.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-8],
            [playBtn.widthAnchor constraintEqualToConstant:34],
            [playBtn.heightAnchor constraintEqualToConstant:34]
        ]];
        [soundStack addArrangedSubview:row];
    }
    [stack addArrangedSubview:soundCard];

    // 5. Protections Card
    UIView *protCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UIStackView *protStack = [[UIStackView alloc] init];
    protStack.translatesAutoresizingMaskIntoConstraints = NO;
    protStack.axis = UILayoutConstraintAxisVertical;
    protStack.spacing = 14;
    [protCard addSubview:protStack];
    [NSLayoutConstraint activateConstraints:@[
        [protStack.topAnchor constraintEqualToAnchor:protCard.topAnchor constant:16],
        [protStack.bottomAnchor constraintEqualToAnchor:protCard.bottomAnchor constant:-16],
        [protStack.leadingAnchor constraintEqualToAnchor:protCard.leadingAnchor constant:16],
        [protStack.trailingAnchor constraintEqualToAnchor:protCard.trailingAnchor constant:-16]
    ]];

    UILabel *protTitle = [[UILabel alloc] init];
    protTitle.text = @"Protezioni Anti-Sonno & Anti-Chiusura";
    protTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    protTitle.textColor = [UIColor whiteColor];
    [protStack addArrangedSubview:protTitle];

    self.lockVolumeSwitch = [[UISwitch alloc] init];
    self.lockVolumeSwitch.on = self.draft.lockVolume;
    [protStack addArrangedSubview:[self makeSwitchRowWithTitle:@"Blocco Volume Fisico al 100%"
                                                      subtitle:@"Impedisce di abbassare la sirena coi tasti volume"
                                                   switchControl:self.lockVolumeSwitch]];

    self.smartQuietSwitch = [[UISwitch alloc] init];
    self.smartQuietSwitch.on = self.draft.smartQuietWhileTyping;
    [protStack addArrangedSubview:[self makeSwitchRowWithTitle:@"Attenua Sirena mentre digiti (6s)"
                                                      subtitle:@"Se ti fermi per più di 6s torna al 100%"
                                                   switchControl:self.smartQuietSwitch]];

    self.wakeUpSwitch = [[UISwitch alloc] init];
    self.wakeUpSwitch.on = self.draft.wakeUpCheckEnabled;
    [protStack addArrangedSubview:[self makeSwitchRowWithTitle:@"Controllo Post-Sveglia (+5 min)"
                                                      subtitle:@"Se non confermi dopo 5 min la sirena riparte"
                                                   switchControl:self.wakeUpSwitch]];

    self.fadeInSwitch = [[UISwitch alloc] init];
    self.fadeInSwitch.on = self.draft.fadeIn;
    [protStack addArrangedSubview:[self makeSwitchRowWithTitle:@"Fade-in Audio Graduale"
                                                      subtitle:@"Volume crescente nei primi 20 secondi"
                                                   switchControl:self.fadeInSwitch]];

    UILabel *noSnooze = [[UILabel alloc] init];
    noSnooze.text = @"🔒 Snooze disabilitato: spegnimento consentito solo risolvendo tutti i calcoli.";
    noSnooze.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    noSnooze.textColor = SVOrangeColor();
    noSnooze.numberOfLines = 0;
    [protStack addArrangedSubview:noSnooze];
    [stack addArrangedSubview:protCard];

    if (self.isEditingAlarm && self.onDelete) {
        UIButton *delBtn = [UIButton buttonWithType:UIButtonTypeSystem];
        [delBtn setTitle:@"Elimina Sveglia" forState:UIControlStateNormal];
        delBtn.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
        [delBtn setTitleColor:[UIColor systemRedColor] forState:UIControlStateNormal];
        delBtn.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.16];
        delBtn.layer.cornerRadius = 16;
        [delBtn.heightAnchor constraintEqualToConstant:48].active = YES;
        [delBtn addTarget:self action:@selector(deleteTapped) forControlEvents:UIControlEventTouchUpInside];
        [stack addArrangedSubview:delBtn];
    }
}

- (UIView *)makeSwitchRowWithTitle:(NSString *)title subtitle:(NSString *)subtitle switchControl:(UISwitch *)sw {
    sw.onTintColor = SVOrangeColor();
    sw.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *container = [[UIView alloc] init];
    UILabel *t = [[UILabel alloc] init];
    t.translatesAutoresizingMaskIntoConstraints = NO;
    t.text = title;
    t.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    t.textColor = [UIColor whiteColor];

    UILabel *s = [[UILabel alloc] init];
    s.translatesAutoresizingMaskIntoConstraints = NO;
    s.text = subtitle;
    s.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    s.textColor = [UIColor colorWithWhite:1.0 alpha:0.58];
    s.numberOfLines = 0;

    [container addSubview:t];
    [container addSubview:s];
    [container addSubview:sw];

    [NSLayoutConstraint activateConstraints:@[
        [t.topAnchor constraintEqualToAnchor:container.topAnchor],
        [t.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [t.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-10],
        [s.topAnchor constraintEqualToAnchor:t.bottomAnchor constant:2],
        [s.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [s.trailingAnchor constraintLessThanOrEqualToAnchor:sw.leadingAnchor constant:-10],
        [s.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [sw.centerYAnchor constraintEqualToAnchor:container.centerYAnchor],
        [sw.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
    ]];
    return container;
}

- (void)dayTapped:(UIButton *)sender {
    NSNumber *day = @(sender.tag);
    NSMutableSet<NSNumber *> *mutable = [self.draft.repeatDays mutableCopy];
    if ([mutable containsObject:day]) {
        [mutable removeObject:day];
    } else {
        [mutable addObject:day];
    }
    self.draft.repeatDays = mutable;
    [self refreshDayButtonsUI];
}

- (void)presetTapped:(UIButton *)sender {
    switch (sender.tag) {
        case 0: self.draft.repeatDays = [NSSet setWithArray:@[@1, @2, @3, @4, @5]]; break;
        case 1: self.draft.repeatDays = [NSSet setWithArray:@[@6, @7]]; break;
        case 2: self.draft.repeatDays = [NSSet setWithArray:@[@1, @2, @3, @4, @5, @6, @7]]; break;
        default: self.draft.repeatDays = [NSSet set]; break;
    }
    [self refreshDayButtonsUI];
}

- (void)refreshDayButtonsUI {
    for (UIButton *btn in self.dayButtons) {
        BOOL selected = [self.draft.repeatDays containsObject:@(btn.tag)];
        btn.backgroundColor = selected ? SVOrangeColor() : [UIColor colorWithWhite:1.0 alpha:0.08];
        [btn setTitleColor:(selected ? [UIColor blackColor] : [UIColor whiteColor]) forState:UIControlStateNormal];
    }
}

- (void)difficultyTapped:(UIButton *)sender {
    self.draft.difficulty = (SVMathDifficulty)sender.tag;
    [self refreshDifficultyUI];
    [self refreshPreviewTapped];
}

- (void)refreshDifficultyUI {
    for (UIButton *btn in self.difficultyButtons) {
        SVMathDifficulty diff = (SVMathDifficulty)btn.tag;
        BOOL selected = (diff == self.draft.difficulty);
        UIColor *accent = SVMathDifficultyColor(diff);
        btn.backgroundColor = selected ? accent : [UIColor colorWithWhite:1.0 alpha:0.07];
        [btn setTitleColor:(selected ? [UIColor blackColor] : accent) forState:UIControlStateNormal];
    }
}

- (void)refreshPreviewTapped {
    SVMathProblem *p = [SVMathGenerator generateWithDifficulty:self.draft.difficulty];
    self.previewEquationLabel.text = [NSString stringWithFormat:@"Es: %@ = %ld", p.expression, (long)p.answer];
}

- (void)stepperChanged:(UIStepper *)sender {
    self.draft.problemCount = (NSInteger)sender.value;
    self.problemCountValueLabel.text = [NSString stringWithFormat:@"%ld", (long)self.draft.problemCount];
}

- (void)soundSelected:(UIButton *)sender {
    self.draft.sound = (SVAlarmSound)sender.tag;
    [self refreshSoundUI];
}

- (void)soundPreviewTapped:(UIButton *)sender {
    [[SVAudioSirenService shared] togglePreviewForSound:(SVAlarmSound)sender.tag];
}

- (void)refreshSoundUI {
    NSInteger previewing = [SVAudioSirenService shared].previewingSoundRaw;
    for (NSUInteger i = 0; i < self.soundSelectButtons.count; i++) {
        UIButton *selBtn = self.soundSelectButtons[i];
        UIButton *playBtn = self.soundPlayButtons[i];
        BOOL isSelected = (self.draft.sound == (SVAlarmSound)i);
        BOOL isPlaying = (previewing == (NSInteger)i);

        NSString *prefix = isSelected ? @"● " : @"○ ";
        [selBtn setTitle:[prefix stringByAppendingString:SVAlarmSoundDisplayName((SVAlarmSound)i)]
                forState:UIControlStateNormal];
        [selBtn setTitleColor:(isSelected ? SVOrangeColor() : [UIColor whiteColor])
                    forState:UIControlStateNormal];

        [playBtn setTitle:(isPlaying ? @"■" : @"▶") forState:UIControlStateNormal];
        [playBtn setTitleColor:(isPlaying ? [UIColor systemRedColor] : [UIColor whiteColor])
                     forState:UIControlStateNormal];
        playBtn.backgroundColor = isPlaying
            ? [[UIColor systemRedColor] colorWithAlphaComponent:0.25]
            : [UIColor colorWithWhite:1.0 alpha:0.10];
    }
}

- (void)cancelTapped {
    [[SVAudioSirenService shared] stopPreview];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)saveTapped {
    [[SVAudioSirenService shared] stopPreview];
    NSDateComponents *comps = [[NSCalendar currentCalendar] components:(NSCalendarUnitHour | NSCalendarUnitMinute)
                                                              fromDate:self.timePicker.date];
    self.draft.hour = comps.hour;
    self.draft.minute = comps.minute;
    self.draft.enabled = YES;

    NSString *trimmed = [self.labelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    self.draft.label = trimmed.length > 0 ? trimmed : @"Sveglia";

    self.draft.lockVolume = self.lockVolumeSwitch.isOn;
    self.draft.smartQuietWhileTyping = self.smartQuietSwitch.isOn;
    self.draft.wakeUpCheckEnabled = self.wakeUpSwitch.isOn;
    self.draft.fadeIn = self.fadeInSwitch.isOn;

    if (self.onSave) {
        self.onSave(self.draft);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)deleteTapped {
    [[SVAudioSirenService shared] stopPreview];
    if (self.onDelete) {
        self.onDelete(self.draft.alarmID);
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end

#pragma mark - SVMathLockViewController

@interface SVMathLockViewController ()

@property (nonatomic, strong) CAGradientLayer *auraLayer;
@property (nonatomic, strong) UILabel *clockLabel;
@property (nonatomic, strong) UILabel *alarmTitleLabel;
@property (nonatomic, strong) UILabel *progressLeftLabel;
@property (nonatomic, strong) UILabel *progressRightLabel;
@property (nonatomic, strong) UIStackView *segmentsStack;
@property (nonatomic, strong) UIView *quietBanner;
@property (nonatomic, strong) UILabel *quietBannerLabel;
@property (nonatomic, strong) UIProgressView *quietProgressView;
@property (nonatomic, strong) UIView *equationCard;
@property (nonatomic, strong) UILabel *expressionLabel;
@property (nonatomic, strong) UIView *answerBox;
@property (nonatomic, strong) UILabel *answerLabel;
@property (nonatomic, strong) UILabel *errorLabel;
@property (nonatomic, strong) UIButton *submitButton;
@property (nonatomic, strong) NSTimer *clockTimer;

@end

@implementation SVMathLockViewController

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.modalInPresentation = YES;

    self.auraLayer = [CAGradientLayer layer];
    self.auraLayer.colors = @[
        (id)[UIColor colorWithRed:1.0 green:0.22 blue:0.14 alpha:0.30].CGColor,
        (id)[UIColor blackColor].CGColor
    ];
    self.auraLayer.locations = @[@0.0, @0.55];
    [self.view.layer insertSublayer:self.auraLayer atIndex:0];

    [self buildLockUI];
    [self refreshLockState];

    __weak typeof(self) weakSelf = self;
    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf updateClock];
    }];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshLockState)
                                                 name:SVAlarmEngineDidChangeStateNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(triggerShakeAnimation)
                                                 name:SVAlarmEngineWrongAnswerNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.auraLayer.frame = self.view.bounds;
}

- (void)dealloc {
    [self.clockTimer invalidate];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildLockUI {
    UIStackView *rootStack = [[UIStackView alloc] init];
    rootStack.translatesAutoresizingMaskIntoConstraints = NO;
    rootStack.axis = UILayoutConstraintAxisVertical;
    rootStack.spacing = 12;
    [self.view addSubview:rootStack];

    [NSLayoutConstraint activateConstraints:@[
        [rootStack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [rootStack.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-10],
        [rootStack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [rootStack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18]
    ]];

    // Header pill + clock + label
    UIView *headerView = [[UIView alloc] init];
    UILabel *lockPill = [[UILabel alloc] init];
    lockPill.translatesAutoresizingMaskIntoConstraints = NO;
    lockPill.text = @"  🔒 BLOCCO ATTIVO • RISOLVI PER SPEGNERE  ";
    lockPill.font = [UIFont systemFontOfSize:11 weight:UIFontWeightBold];
    lockPill.textColor = [UIColor colorWithRed:1.0 green:0.38 blue:0.32 alpha:1.0];
    lockPill.backgroundColor = [[UIColor systemRedColor] colorWithAlphaComponent:0.24];
    lockPill.layer.cornerRadius = 12;
    lockPill.clipsToBounds = YES;

    self.clockLabel = [[UILabel alloc] init];
    self.clockLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.clockLabel.font = [UIFont monospacedDigitSystemFontOfSize:36 weight:UIFontWeightBold];
    self.clockLabel.textColor = [UIColor whiteColor];
    self.clockLabel.textAlignment = NSTextAlignmentCenter;

    self.alarmTitleLabel = [[UILabel alloc] init];
    self.alarmTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.alarmTitleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    self.alarmTitleLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.68];
    self.alarmTitleLabel.textAlignment = NSTextAlignmentCenter;

    [headerView addSubview:lockPill];
    [headerView addSubview:self.clockLabel];
    [headerView addSubview:self.alarmTitleLabel];
    [NSLayoutConstraint activateConstraints:@[
        [lockPill.topAnchor constraintEqualToAnchor:headerView.topAnchor],
        [lockPill.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [lockPill.heightAnchor constraintEqualToConstant:24],
        [self.clockLabel.topAnchor constraintEqualToAnchor:lockPill.bottomAnchor constant:6],
        [self.clockLabel.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [self.alarmTitleLabel.topAnchor constraintEqualToAnchor:self.clockLabel.bottomAnchor constant:2],
        [self.alarmTitleLabel.centerXAnchor constraintEqualToAnchor:headerView.centerXAnchor],
        [self.alarmTitleLabel.bottomAnchor constraintEqualToAnchor:headerView.bottomAnchor]
    ]];
    [rootStack addArrangedSubview:headerView];

    // Progress section
    UIView *progressWrap = [[UIView alloc] init];
    self.progressLeftLabel = [[UILabel alloc] init];
    self.progressLeftLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressLeftLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.progressLeftLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.82];

    self.progressRightLabel = [[UILabel alloc] init];
    self.progressRightLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.progressRightLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightRegular];
    self.progressRightLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.55];

    self.segmentsStack = [[UIStackView alloc] init];
    self.segmentsStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentsStack.distribution = UIStackViewDistributionFillEqually;
    self.segmentsStack.spacing = 6;

    [progressWrap addSubview:self.progressLeftLabel];
    [progressWrap addSubview:self.progressRightLabel];
    [progressWrap addSubview:self.segmentsStack];
    [NSLayoutConstraint activateConstraints:@[
        [self.progressLeftLabel.topAnchor constraintEqualToAnchor:progressWrap.topAnchor],
        [self.progressLeftLabel.leadingAnchor constraintEqualToAnchor:progressWrap.leadingAnchor],
        [self.progressRightLabel.centerYAnchor constraintEqualToAnchor:self.progressLeftLabel.centerYAnchor],
        [self.progressRightLabel.trailingAnchor constraintEqualToAnchor:progressWrap.trailingAnchor],
        [self.segmentsStack.topAnchor constraintEqualToAnchor:self.progressLeftLabel.bottomAnchor constant:6],
        [self.segmentsStack.leadingAnchor constraintEqualToAnchor:progressWrap.leadingAnchor],
        [self.segmentsStack.trailingAnchor constraintEqualToAnchor:progressWrap.trailingAnchor],
        [self.segmentsStack.heightAnchor constraintEqualToConstant:6],
        [self.segmentsStack.bottomAnchor constraintEqualToAnchor:progressWrap.bottomAnchor]
    ]];
    [rootStack addArrangedSubview:progressWrap];

    // Quiet banner
    self.quietBanner = SVMakeCardView(12, [UIColor colorWithWhite:1.0 alpha:0.06], [UIColor clearColor]);
    self.quietBannerLabel = [[UILabel alloc] init];
    self.quietBannerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.quietBannerLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightSemibold];
    self.quietBannerLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.75];

    self.quietProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    self.quietProgressView.translatesAutoresizingMaskIntoConstraints = NO;
    self.quietProgressView.trackTintColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    self.quietProgressView.progressTintColor = SVGreenColor();

    [self.quietBanner addSubview:self.quietBannerLabel];
    [self.quietBanner addSubview:self.quietProgressView];
    [NSLayoutConstraint activateConstraints:@[
        [self.quietBannerLabel.topAnchor constraintEqualToAnchor:self.quietBanner.topAnchor constant:8],
        [self.quietBannerLabel.leadingAnchor constraintEqualToAnchor:self.quietBanner.leadingAnchor constant:12],
        [self.quietBannerLabel.trailingAnchor constraintEqualToAnchor:self.quietBanner.trailingAnchor constant:-12],
        [self.quietProgressView.topAnchor constraintEqualToAnchor:self.quietBannerLabel.bottomAnchor constant:6],
        [self.quietProgressView.leadingAnchor constraintEqualToAnchor:self.quietBanner.leadingAnchor constant:12],
        [self.quietProgressView.trailingAnchor constraintEqualToAnchor:self.quietBanner.trailingAnchor constant:-12],
        [self.quietProgressView.heightAnchor constraintEqualToConstant:4],
        [self.quietProgressView.bottomAnchor constraintEqualToAnchor:self.quietBanner.bottomAnchor constant:-8]
    ]];
    [rootStack addArrangedSubview:self.quietBanner];

    UIView *spacerTop = [[UIView alloc] init];
    [spacerTop setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisVertical];
    [rootStack addArrangedSubview:spacerTop];

    // Equation card
    self.equationCard = SVMakeCardView(24, [UIColor colorWithRed:0.09 green:0.10 blue:0.12 alpha:1.0], [UIColor colorWithWhite:1.0 alpha:0.12]);
    self.expressionLabel = [[UILabel alloc] init];
    self.expressionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.expressionLabel.font = [UIFont monospacedDigitSystemFontOfSize:38 weight:UIFontWeightBold];
    self.expressionLabel.textColor = [UIColor whiteColor];
    self.expressionLabel.textAlignment = NSTextAlignmentCenter;
    self.expressionLabel.adjustsFontSizeToFitWidth = YES;
    self.expressionLabel.minimumScaleFactor = 0.45;

    self.answerBox = SVMakeCardView(16, [UIColor colorWithWhite:0.0 alpha:0.70], [UIColor colorWithWhite:1.0 alpha:0.16]);
    UILabel *eqSign = [[UILabel alloc] init];
    eqSign.translatesAutoresizingMaskIntoConstraints = NO;
    eqSign.text = @"=";
    eqSign.font = [UIFont systemFontOfSize:30 weight:UIFontWeightBold];
    eqSign.textColor = SVOrangeColor();

    self.answerLabel = [[UILabel alloc] init];
    self.answerLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.answerLabel.textAlignment = NSTextAlignmentCenter;
    self.answerLabel.font = [UIFont monospacedDigitSystemFontOfSize:34 weight:UIFontWeightBold];

    [self.answerBox addSubview:eqSign];
    [self.answerBox addSubview:self.answerLabel];
    [NSLayoutConstraint activateConstraints:@[
        [eqSign.leadingAnchor constraintEqualToAnchor:self.answerBox.leadingAnchor constant:16],
        [eqSign.centerYAnchor constraintEqualToAnchor:self.answerBox.centerYAnchor],
        [self.answerLabel.topAnchor constraintEqualToAnchor:self.answerBox.topAnchor constant:12],
        [self.answerLabel.bottomAnchor constraintEqualToAnchor:self.answerBox.bottomAnchor constant:-12],
        [self.answerLabel.leadingAnchor constraintEqualToAnchor:eqSign.trailingAnchor constant:8],
        [self.answerLabel.trailingAnchor constraintEqualToAnchor:self.answerBox.trailingAnchor constant:-16],
        [self.answerLabel.heightAnchor constraintGreaterThanOrEqualToConstant:40]
    ]];

    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.text = @"Risposta errata! Controlla il calcolo e riprova.";
    self.errorLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.errorLabel.textColor = [UIColor colorWithRed:1.0 green:0.35 blue:0.32 alpha:1.0];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.hidden = YES;

    [self.equationCard addSubview:self.expressionLabel];
    [self.equationCard addSubview:self.answerBox];
    [self.equationCard addSubview:self.errorLabel];
    [NSLayoutConstraint activateConstraints:@[
        [self.expressionLabel.topAnchor constraintEqualToAnchor:self.equationCard.topAnchor constant:18],
        [self.expressionLabel.leadingAnchor constraintEqualToAnchor:self.equationCard.leadingAnchor constant:16],
        [self.expressionLabel.trailingAnchor constraintEqualToAnchor:self.equationCard.trailingAnchor constant:-16],
        [self.answerBox.topAnchor constraintEqualToAnchor:self.expressionLabel.bottomAnchor constant:14],
        [self.answerBox.leadingAnchor constraintEqualToAnchor:self.equationCard.leadingAnchor constant:18],
        [self.answerBox.trailingAnchor constraintEqualToAnchor:self.equationCard.trailingAnchor constant:-18],
        [self.errorLabel.topAnchor constraintEqualToAnchor:self.answerBox.bottomAnchor constant:8],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:self.equationCard.leadingAnchor constant:16],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:self.equationCard.trailingAnchor constant:-16],
        [self.errorLabel.bottomAnchor constraintEqualToAnchor:self.equationCard.bottomAnchor constant:-14]
    ]];
    [rootStack addArrangedSubview:self.equationCard];

    UIView *spacerBottom = [[UIView alloc] init];
    [spacerBottom.heightAnchor constraintEqualToAnchor:spacerTop.heightAnchor].active = YES;
    [rootStack addArrangedSubview:spacerBottom];

    // Numeric Keypad (4 x 3)
    UIStackView *keypadStack = [[UIStackView alloc] init];
    keypadStack.axis = UILayoutConstraintAxisVertical;
    keypadStack.spacing = 10;

    NSArray<NSArray<NSNumber *> *> *layout = @[
        @[@1, @2, @3],
        @[@4, @5, @6],
        @[@7, @8, @9],
        @[@(-1), @0, @(-2)]
    ];

    for (NSArray<NSNumber *> *rowItems in layout) {
        UIStackView *rowStack = [[UIStackView alloc] init];
        rowStack.distribution = UIStackViewDistributionFillEqually;
        rowStack.spacing = 10;

        for (NSNumber *num in rowItems) {
            NSInteger val = num.integerValue;
            UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
            btn.tag = val;
            btn.layer.cornerRadius = 18;
            if (@available(iOS 13.0, *)) {
                btn.layer.cornerCurve = kCACornerCurveContinuous;
            }
            [btn.heightAnchor constraintEqualToConstant:60].active = YES;

            if (val >= 0) {
                [btn setTitle:[NSString stringWithFormat:@"%ld", (long)val] forState:UIControlStateNormal];
                btn.titleLabel.font = [UIFont systemFontOfSize:28 weight:UIFontWeightSemibold];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                btn.backgroundColor = [UIColor colorWithRed:0.12 green:0.13 blue:0.16 alpha:1.0];
            } else if (val == -1) {
                [btn setTitle:@"⌫" forState:UIControlStateNormal];
                btn.titleLabel.font = [UIFont systemFontOfSize:24 weight:UIFontWeightSemibold];
                [btn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                btn.backgroundColor = [UIColor colorWithRed:0.18 green:0.12 blue:0.12 alpha:1.0];
            } else {
                [btn setTitle:@"OK ✓" forState:UIControlStateNormal];
                btn.titleLabel.font = [UIFont systemFontOfSize:22 weight:UIFontWeightBold];
                [btn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
                btn.backgroundColor = SVGreenColor();
                self.submitButton = btn;
            }
            [btn addTarget:self action:@selector(keypadTapped:) forControlEvents:UIControlEventTouchUpInside];
            [rowStack addArrangedSubview:btn];
        }
        [keypadStack addArrangedSubview:rowStack];
    }
    [rootStack addArrangedSubview:keypadStack];
    [self updateClock];
}

- (void)updateClock {
    NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
    fmt.dateFormat = @"HH:mm:ss";
    self.clockLabel.text = [fmt stringFromDate:[NSDate date]];
}

- (void)refreshLockState {
    SVAlarmEngine *engine = [SVAlarmEngine shared];
    SVAudioSirenService *audio = [SVAudioSirenService shared];
    SVAlarmItem *alarm = engine.activeAlarm;

    if (alarm) {
        self.alarmTitleLabel.text = [NSString stringWithFormat:@"%@ • %@", alarm.label, SVMathDifficultyTitle(alarm.difficulty)];
    }

    NSInteger total = MAX(1, (NSInteger)engine.currentProblems.count);
    NSInteger currentIdx = MIN(engine.solvedCount + 1, total);
    self.progressLeftLabel.text = [NSString stringWithFormat:@"Calcolo %ld di %ld", (long)currentIdx, (long)total];
    self.progressRightLabel.text = [NSString stringWithFormat:@"%ld/%ld risolti", (long)engine.solvedCount, (long)total];

    for (UIView *v in [self.segmentsStack.arrangedSubviews copy]) {
        [self.segmentsStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }
    for (NSInteger i = 0; i < total; i++) {
        UIView *seg = [[UIView alloc] init];
        seg.layer.cornerRadius = 3;
        if (i < engine.solvedCount) {
            seg.backgroundColor = SVGreenColor();
        } else if (i == engine.solvedCount) {
            seg.backgroundColor = SVOrangeColor();
        } else {
            seg.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
        }
        [self.segmentsStack addArrangedSubview:seg];
    }

    if (alarm && alarm.smartQuietWhileTyping) {
        self.quietBanner.hidden = NO;
        if (audio.isQuietWindowActive) {
            self.quietBannerLabel.text = [NSString stringWithFormat:@"🎧 Sirena attenuata mentre scrivi • %.1fs", audio.quietRemainingSeconds];
            self.quietBannerLabel.textColor = SVGreenColor();
            self.quietProgressView.hidden = NO;
            self.quietProgressView.progress = (float)MAX(0.0, MIN(1.0, audio.quietRemainingSeconds / audio.quietWindowDuration));
        } else {
            self.quietBannerLabel.text = @"🔊 Sirena al 100% — inizia a digitare per attenuare 6s";
            self.quietBannerLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
            self.quietProgressView.hidden = YES;
        }
    } else {
        self.quietBanner.hidden = YES;
    }

    SVMathProblem *prob = engine.currentProblem;
    self.expressionLabel.text = prob ? prob.expression : @"...";

    if (engine.userInput.length == 0) {
        self.answerLabel.text = @"Inserisci risposta";
        self.answerLabel.font = [UIFont systemFontOfSize:20 weight:UIFontWeightBold];
        self.answerLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.32];
        self.submitButton.backgroundColor = [SVOrangeColor() colorWithAlphaComponent:0.50];
    } else {
        self.answerLabel.text = engine.userInput;
        self.answerLabel.font = [UIFont monospacedDigitSystemFontOfSize:34 weight:UIFontWeightBold];
        self.answerLabel.textColor = [UIColor whiteColor];
        self.submitButton.backgroundColor = SVGreenColor();
    }

    self.errorLabel.hidden = !engine.wrongBannerVisible;
    self.answerBox.layer.borderColor = engine.wrongBannerVisible
        ? [UIColor systemRedColor].CGColor
        : [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
    self.answerBox.layer.borderWidth = engine.wrongBannerVisible ? 2.0 : 1.0;
}

- (void)keypadTapped:(UIButton *)sender {
    NSInteger val = sender.tag;
    if (val >= 0) {
        [[SVAlarmEngine shared] appendDigit:[NSString stringWithFormat:@"%ld", (long)val]];
    } else if (val == -1) {
        [[SVAlarmEngine shared] deleteLastDigit];
    } else {
        [[SVAlarmEngine shared] submitAnswer];
    }
}

- (void)triggerShakeAnimation {
    CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"transform.translation.x"];
    anim.values = @[@(-12), @12, @(-10), @10, @(-5), @5, @0];
    anim.duration = 0.30;
    [self.answerBox.layer addAnimation:anim forKey:@"shake"];
}

@end

#pragma mark - SVPracticeSettingsViewController

@interface SVPracticeSettingsViewController ()

@property (nonatomic, strong) UISegmentedControl *difficultyControl;
@property (nonatomic, strong) UILabel *streakLabel;
@property (nonatomic, strong) UILabel *practiceExprLabel;
@property (nonatomic, strong) UITextField *practiceField;
@property (nonatomic, strong) UILabel *practiceFeedbackLabel;
@property (nonatomic, strong) UILabel *notifStatusValueLabel;
@property (nonatomic, strong) UIButton *openSettingsButton;

@property (nonatomic, strong) SVMathProblem *currentPracticeProblem;
@property (nonatomic, assign) NSInteger streakCount;

@end

@implementation SVPracticeSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    self.title = @"Sistema & Allenamento";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    SVStyleDarkNavBar(self.navigationController.navigationBar);

    self.currentPracticeProblem = [SVMathGenerator generateWithDifficulty:SVMathDifficultyMedium];
    [self buildUI];
    [self refreshStatuses];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refreshStatuses)
                                                 name:SVAlarmEngineDidChangeStateNotification
                                               object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)buildUI {
    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeInteractive;
    [self.view addSubview:scroll];

    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 16;
    [scroll addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [scroll.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],

        [stack.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:12],
        [stack.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-28],
        [stack.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],
        [stack.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32]
    ]];

    // 1. Practice Card
    UIView *practiceCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UIStackView *pStack = [[UIStackView alloc] init];
    pStack.translatesAutoresizingMaskIntoConstraints = NO;
    pStack.axis = UILayoutConstraintAxisVertical;
    pStack.spacing = 12;
    [practiceCard addSubview:pStack];
    [NSLayoutConstraint activateConstraints:@[
        [pStack.topAnchor constraintEqualToAnchor:practiceCard.topAnchor constant:16],
        [pStack.bottomAnchor constraintEqualToAnchor:practiceCard.bottomAnchor constant:-16],
        [pStack.leadingAnchor constraintEqualToAnchor:practiceCard.leadingAnchor constant:16],
        [pStack.trailingAnchor constraintEqualToAnchor:practiceCard.trailingAnchor constant:-16]
    ]];

    UIStackView *pHead = [[UIStackView alloc] init];
    UILabel *pTitle = [[UILabel alloc] init];
    pTitle.text = @"🧠 Allenamento Silenzioso";
    pTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    pTitle.textColor = [UIColor whiteColor];

    self.streakLabel = [[UILabel alloc] init];
    self.streakLabel.text = @"  Serie: 0  ";
    self.streakLabel.font = [UIFont monospacedDigitSystemFontOfSize:12 weight:UIFontWeightBold];
    self.streakLabel.textColor = SVOrangeColor();
    self.streakLabel.backgroundColor = [SVOrangeColor() colorWithAlphaComponent:0.20];
    self.streakLabel.layer.cornerRadius = 11;
    self.streakLabel.clipsToBounds = YES;
    [pHead addArrangedSubview:pTitle];
    [pHead addArrangedSubview:self.streakLabel];
    [pStack addArrangedSubview:pHead];

    self.difficultyControl = [[UISegmentedControl alloc] initWithItems:@[@"Facile", @"Medio", @"Difficile", @"Estremo"]];
    self.difficultyControl.selectedSegmentIndex = 1;
    [self.difficultyControl addTarget:self action:@selector(practiceDifficultyChanged:) forControlEvents:UIControlEventValueChanged];
    [pStack addArrangedSubview:self.difficultyControl];

    self.practiceExprLabel = [[UILabel alloc] init];
    self.practiceExprLabel.text = self.currentPracticeProblem.expression;
    self.practiceExprLabel.font = [UIFont monospacedDigitSystemFontOfSize:30 weight:UIFontWeightBold];
    self.practiceExprLabel.textColor = [UIColor whiteColor];
    self.practiceExprLabel.textAlignment = NSTextAlignmentCenter;
    [pStack addArrangedSubview:self.practiceExprLabel];

    UIStackView *inputRow = [[UIStackView alloc] init];
    inputRow.spacing = 10;

    self.practiceField = [[UITextField alloc] init];
    self.practiceField.placeholder = @"Risultato";
    self.practiceField.keyboardType = UIKeyboardTypeNumberPad;
    self.practiceField.textColor = [UIColor whiteColor];
    self.practiceField.textAlignment = NSTextAlignmentCenter;
    self.practiceField.font = [UIFont monospacedDigitSystemFontOfSize:20 weight:UIFontWeightBold];
    self.practiceField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.practiceField.layer.cornerRadius = 12;
    [self.practiceField.heightAnchor constraintEqualToConstant:44].active = YES;

    UIButton *verifyBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [verifyBtn setTitle:@"  Verifica  " forState:UIControlStateNormal];
    verifyBtn.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightBold];
    [verifyBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    verifyBtn.backgroundColor = SVOrangeColor();
    verifyBtn.layer.cornerRadius = 12;
    [verifyBtn.widthAnchor constraintEqualToConstant:96].active = YES;
    [verifyBtn addTarget:self action:@selector(verifyPracticeTapped) forControlEvents:UIControlEventTouchUpInside];

    [inputRow addArrangedSubview:self.practiceField];
    [inputRow addArrangedSubview:verifyBtn];
    [pStack addArrangedSubview:inputRow];

    self.practiceFeedbackLabel = [[UILabel alloc] init];
    self.practiceFeedbackLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    self.practiceFeedbackLabel.textAlignment = NSTextAlignmentCenter;
    self.practiceFeedbackLabel.hidden = YES;
    [pStack addArrangedSubview:self.practiceFeedbackLabel];

    [stack addArrangedSubview:practiceCard];

    // 2. System Status Card
    UIView *statusCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UIStackView *sStack = [[UIStackView alloc] init];
    sStack.translatesAutoresizingMaskIntoConstraints = NO;
    sStack.axis = UILayoutConstraintAxisVertical;
    sStack.spacing = 10;
    [statusCard addSubview:sStack];
    [NSLayoutConstraint activateConstraints:@[
        [sStack.topAnchor constraintEqualToAnchor:statusCard.topAnchor constant:16],
        [sStack.bottomAnchor constraintEqualToAnchor:statusCard.bottomAnchor constant:-16],
        [sStack.leadingAnchor constraintEqualToAnchor:statusCard.leadingAnchor constant:16],
        [sStack.trailingAnchor constraintEqualToAnchor:statusCard.trailingAnchor constant:-16]
    ]];

    UILabel *sTitle = [[UILabel alloc] init];
    sTitle.text = @"Stato Motore Sveglia (iOS 27)";
    sTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    sTitle.textColor = [UIColor whiteColor];
    [sStack addArrangedSubview:sTitle];

    UILabel *hydraTitle = [[UILabel alloc] init];
    hydraTitle.text = @"Notifiche Catena Hydra (0% Batteria)";
    hydraTitle.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    hydraTitle.textColor = [UIColor whiteColor];
    [sStack addArrangedSubview:hydraTitle];

    self.notifStatusValueLabel = [[UILabel alloc] init];
    self.notifStatusValueLabel.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    self.notifStatusValueLabel.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
    [sStack addArrangedSubview:self.notifStatusValueLabel];

    UILabel *audioInfo = [[UILabel alloc] init];
    audioInfo.text = @"Sirena Background & VolumeGuard: Pronti (UIBackgroundModes audio)";
    audioInfo.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    audioInfo.textColor = SVGreenColor();
    audioInfo.numberOfLines = 0;
    [sStack addArrangedSubview:audioInfo];

    UIStackView *btnRow = [[UIStackView alloc] init];
    btnRow.distribution = UIStackViewDistributionFillEqually;
    btnRow.spacing = 10;

    UIButton *permBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [permBtn setTitle:@"Aggiorna Permessi" forState:UIControlStateNormal];
    permBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [permBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    permBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    permBtn.layer.cornerRadius = 12;
    [permBtn.heightAnchor constraintEqualToConstant:40].active = YES;
    [permBtn addTarget:self action:@selector(refreshPermissionsTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *simBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [simBtn setTitle:@"Simula Blocco Ora" forState:UIControlStateNormal];
    simBtn.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightBold];
    [simBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    simBtn.backgroundColor = SVOrangeColor();
    simBtn.layer.cornerRadius = 12;
    [simBtn.heightAnchor constraintEqualToConstant:40].active = YES;
    [simBtn addTarget:self action:@selector(simulateTapped) forControlEvents:UIControlEventTouchUpInside];

    [btnRow addArrangedSubview:permBtn];
    [btnRow addArrangedSubview:simBtn];
    [sStack addArrangedSubview:btnRow];

    self.openSettingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.openSettingsButton setTitle:@"Apri Impostazioni iOS" forState:UIControlStateNormal];
    self.openSettingsButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.openSettingsButton setTitleColor:SVOrangeColor() forState:UIControlStateNormal];
    self.openSettingsButton.hidden = YES;
    [self.openSettingsButton addTarget:self action:@selector(openIOSSettingsTapped) forControlEvents:UIControlEventTouchUpInside];
    [sStack addArrangedSubview:self.openSettingsButton];

    [stack addArrangedSubview:statusCard];

    // 3. Shortcuts Guide Card
    UIView *guideCard = SVMakeCardView(20, SVCardBgColor(), [UIColor colorWithWhite:1.0 alpha:0.09]);
    UILabel *guideTitle = [[UILabel alloc] init];
    guideTitle.translatesAutoresizingMaskIntoConstraints = NO;
    guideTitle.text = @"📱 Blocco Hardware Totale (iOS 27)";
    guideTitle.font = [UIFont systemFontOfSize:17 weight:UIFontWeightBold];
    guideTitle.textColor = [UIColor whiteColor];

    UILabel *guideBody = [[UILabel alloc] init];
    guideBody.translatesAutoresizingMaskIntoConstraints = NO;
    guideBody.numberOfLines = 0;
    guideBody.font = [UIFont systemFontOfSize:12 weight:UIFontWeightRegular];
    guideBody.textColor = [UIColor colorWithWhite:1.0 alpha:0.78];
    guideBody.text = @"iOS non permette alle app di disabilitare i tasti fisici o lo swipe verso la Home. Con Comandi Rapidi puoi renderla 100% inaggirabile:\n\n"
                     @"1. Apri Comandi Rapidi → Automazione → Crea Automazione Personale → Ora del giorno → Esegui immediatamente.\n"
                     @"2. Aggiungi \"Imposta volume multimediale\" al 100%.\n"
                     @"3. Aggiungi \"Apri app\" → Sveglia.\n"
                     @"4. Opzionale: aggiungi \"Avvia Accesso Guidato\" per bloccare anche lo swipe Home finché non inserisci il PIN.";

    [guideCard addSubview:guideTitle];
    [guideCard addSubview:guideBody];
    [NSLayoutConstraint activateConstraints:@[
        [guideTitle.topAnchor constraintEqualToAnchor:guideCard.topAnchor constant:16],
        [guideTitle.leadingAnchor constraintEqualToAnchor:guideCard.leadingAnchor constant:16],
        [guideTitle.trailingAnchor constraintEqualToAnchor:guideCard.trailingAnchor constant:-16],
        [guideBody.topAnchor constraintEqualToAnchor:guideTitle.bottomAnchor constant:8],
        [guideBody.leadingAnchor constraintEqualToAnchor:guideCard.leadingAnchor constant:16],
        [guideBody.trailingAnchor constraintEqualToAnchor:guideCard.trailingAnchor constant:-16],
        [guideBody.bottomAnchor constraintEqualToAnchor:guideCard.bottomAnchor constant:-16]
    ]];
    [stack addArrangedSubview:guideCard];
}

- (void)practiceDifficultyChanged:(UISegmentedControl *)sender {
    SVMathDifficulty diff = (SVMathDifficulty)sender.selectedSegmentIndex;
    self.currentPracticeProblem = [SVMathGenerator generateWithDifficulty:diff];
    self.practiceExprLabel.text = self.currentPracticeProblem.expression;
    self.practiceField.text = @"";
    self.practiceFeedbackLabel.hidden = YES;
}

- (void)verifyPracticeTapped {
    [self.practiceField resignFirstResponder];
    NSString *trimmed = [self.practiceField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    BOOL valid = trimmed.length > 0;
    NSInteger val = valid ? [trimmed integerValue] : NSIntegerMin;

    self.practiceFeedbackLabel.hidden = NO;
    if (valid && val == self.currentPracticeProblem.answer) {
        self.streakCount++;
        self.practiceFeedbackLabel.text = [NSString stringWithFormat:@"Esatto! (%@ = %ld)", self.currentPracticeProblem.expression, (long)self.currentPracticeProblem.answer];
        self.practiceFeedbackLabel.textColor = SVGreenColor();
        SVMathDifficulty diff = (SVMathDifficulty)self.difficultyControl.selectedSegmentIndex;
        self.currentPracticeProblem = [SVMathGenerator generateWithDifficulty:diff];
        self.practiceExprLabel.text = self.currentPracticeProblem.expression;
        self.practiceField.text = @"";
    } else {
        self.streakCount = 0;
        self.practiceFeedbackLabel.text = @"Sbagliato, riprova!";
        self.practiceFeedbackLabel.textColor = [UIColor systemRedColor];
        self.practiceField.text = @"";
    }
    self.streakLabel.text = [NSString stringWithFormat:@"  Serie: %ld  ", (long)self.streakCount];
}

- (void)refreshStatuses {
    UNAuthorizationStatus status = [SVAlarmEngine shared].notificationStatus;
    switch (status) {
        case UNAuthorizationStatusAuthorized:
            self.notifStatusValueLabel.text = @"Autorizzate (Time-Sensitive attive)";
            self.notifStatusValueLabel.textColor = SVGreenColor();
            self.openSettingsButton.hidden = YES;
            break;
        case UNAuthorizationStatusDenied:
            self.notifStatusValueLabel.text = @"Negate nelle Impostazioni iOS";
            self.notifStatusValueLabel.textColor = [UIColor systemRedColor];
            self.openSettingsButton.hidden = NO;
            break;
        case UNAuthorizationStatusProvisional:
            self.notifStatusValueLabel.text = @"Provvisorie";
            self.notifStatusValueLabel.textColor = [UIColor systemYellowColor];
            self.openSettingsButton.hidden = YES;
            break;
        default:
            self.notifStatusValueLabel.text = @"Non ancora richieste";
            self.notifStatusValueLabel.textColor = [UIColor systemYellowColor];
            self.openSettingsButton.hidden = YES;
            break;
    }
}

- (void)refreshPermissionsTapped {
    [[SVAlarmEngine shared] requestPermissionsWithCompletion:nil];
}

- (void)simulateTapped {
    SVAlarmEngine *engine = [SVAlarmEngine shared];
    SVAlarmItem *target = nil;
    for (SVAlarmItem *item in engine.alarms) {
        if (item.enabled) {
            target = item;
            break;
        }
    }
    if (!target) {
        target = engine.alarms.firstObject ?: [[SVAlarmItem alloc] initWithDefaultValues];
    }
    [engine triggerTestAlarm:target];
}

- (void)openIOSSettingsTapped {
    NSURL *url = [NSURL URLWithString:UIApplicationOpenSettingsURLString];
    if (url) {
        [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
    }
}

@end

#pragma mark - SVRootContainerViewController

@interface SVRootContainerViewController ()

@property (nonatomic, strong) UITabBarController *tabController;
@property (nonatomic, strong, nullable) SVMathLockViewController *lockVC;

@end

@implementation SVRootContainerViewController

- (BOOL)prefersHomeIndicatorAutoHidden {
    return [[SVAlarmEngine shared] isRinging];
}

- (UIViewController *)childViewControllerForHomeIndicatorAutoHidden {
    return self.lockVC;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor blackColor];
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    self.tabController = [[UITabBarController alloc] init];
    self.tabController.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;

    UITabBarAppearance *tabApp = [[UITabBarAppearance alloc] init];
    [tabApp configureWithOpaqueBackground];
    tabApp.backgroundColor = [UIColor blackColor];
    self.tabController.tabBar.standardAppearance = tabApp;
    if (@available(iOS 15.0, *)) {
        self.tabController.tabBar.scrollEdgeAppearance = tabApp;
    }
    self.tabController.tabBar.tintColor = SVOrangeColor();

    SVAlarmListViewController *listVC = [[SVAlarmListViewController alloc] init];
    UINavigationController *nav1 = [[UINavigationController alloc] initWithRootViewController:listVC];
    nav1.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Sveglie"
                                                    image:[UIImage systemImageNamed:@"alarm.fill"]
                                                      tag:0];

    SVPracticeSettingsViewController *settingsVC = [[SVPracticeSettingsViewController alloc] init];
    UINavigationController *nav2 = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    nav2.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Sistema & Allenamento"
                                                    image:[UIImage systemImageNamed:@"lock.shield.fill"]
                                                      tag:1];

    self.tabController.viewControllers = @[nav1, nav2];

    [self addChildViewController:self.tabController];
    self.tabController.view.frame = self.view.bounds;
    self.tabController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:self.tabController.view];
    [self.tabController didMoveToParentViewController:self];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(syncRingingOverlay)
                                                 name:SVAlarmEngineDidChangeStateNotification
                                               object:nil];
    [self syncRingingOverlay];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)syncRingingOverlay {
    BOOL ringing = [[SVAlarmEngine shared] isRinging];
    if (ringing && !self.lockVC) {
        if (self.tabController.presentedViewController) {
            [self.tabController dismissViewControllerAnimated:NO completion:nil];
        }
        if (self.presentedViewController) {
            [self dismissViewControllerAnimated:NO completion:nil];
        }
        SVMathLockViewController *lock = [[SVMathLockViewController alloc] init];
        [self addChildViewController:lock];
        lock.view.frame = self.view.bounds;
        lock.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:lock.view];
        [lock didMoveToParentViewController:self];
        self.lockVC = lock;
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    } else if (!ringing && self.lockVC) {
        [self.lockVC willMoveToParentViewController:nil];
        [self.lockVC.view removeFromSuperview];
        [self.lockVC removeFromParentViewController];
        self.lockVC = nil;
        [self setNeedsUpdateOfHomeIndicatorAutoHidden];
    }
}

@end
