import { router } from '@kit.ArkUI'

interface StudyGoal {
  title: string
  targetHours: number
  finishedHours: number
}

interface PlanItem {
  title: string
  subject: string
  minutes: number
  finished: boolean
}

@Entry
@Component
struct TaskPage {
  // 接收从首页传过来的参数
  @State receivedFocusMinutes: number = 0
  @State receivedCompletedCount: number = 0
  @State receivedTaskTotal: number = 0

  // 页面出现时接收路由参数
  aboutToAppear(): void {
    let params = router.getParams() as Record<string, number>
    if (params !== undefined && params !== null) {
      this.receivedFocusMinutes = params['focusMinutes'] ?? 0
      this.receivedCompletedCount = params['completedCount'] ?? 0
      this.receivedTaskTotal = params['taskTotal'] ?? 0
    }
    
  }
  // 对象数据：完成学习后整体重新赋值，触发界面刷新
  @State studyGoal: StudyGoal = {
    title: '本周学习目标',
    targetHours: 10,
    finishedHours: 6
  }

  // 数组数据：数组中的每一项都是 PlanItem 对象
  @State plans: PlanItem[] = [
    {
      title: '复习英语',
      subject: '英语',
      minutes: 30,
      finished: false
    },
    {
      title: '学习数据结构',
      subject: '数据结构',
      minutes: 60,
      finished: true
    },
    {
      title: '练习 ArkTS',
      subject: '鸿蒙开发',
      minutes: 40,
      finished: false
    }
  ]

  private getGoalProgress(): number {
    if (this.studyGoal.targetHours === 0) {
      return 0
    }

    return Math.round(this.studyGoal.finishedHours / this.studyGoal.targetHours * 100)
  }

  // 修改 studyGoal 对象并整体赋回 @State
  private addFinishedHour(): void {
    if (this.studyGoal.finishedHours >= this.studyGoal.targetHours) {
      return
    }

    this.studyGoal = {
      title: this.studyGoal.title,
      targetHours: this.studyGoal.targetHours,
      finishedHours: this.studyGoal.finishedHours + 1
    }
    //把新增的 1 小时 = 60 分钟存到 AppStorage，供首页读取
    AppStorage.setOrCreate<number>('extraFocusMinutes',
      (AppStorage.get<number>('extraFocusMinutes') ?? 0) + 60)
  }

  // 切换数组中对应 PlanItem 对象的 finished 状态
  private togglePlan(index: number): void {
    let selectedPlan: PlanItem = this.plans[index]
    let updatedPlans: PlanItem[] = this.plans.slice()
    updatedPlans[index] = {
      title: selectedPlan.title,
      subject: selectedPlan.subject,
      minutes: selectedPlan.minutes,
      finished: !selectedPlan.finished
    }
    this.plans = updatedPlans
  }

  // push 新对象后，@State 数组会驱动 List 自动刷新
  private addPlan(): void {
    let newPlan: PlanItem = {
      title: `新增学习任务 ${this.plans.length + 1}`,
      subject: '软件工程',
      minutes: 45,
      finished: false
    }
    this.plans.push(newPlan)
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Column() {
          Text('学习计划')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111111')

          Text('管理你的学习任务与目标')
            .fontSize(14)
            .fontColor('#8A94A6')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('PLAN')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#4F7CFF')
          .backgroundColor('#E8EEFF')
          .padding({
            left: 12,
            right: 12,
            top: 6,
            bottom: 6
          })
          .borderRadius(12)
      }
      .width('100%')
      .margin({ bottom: 20 })

      // StudyGoal 对象数据显示卡片
      Column() {
        Row() {
          Column() {
            Text(this.studyGoal.title)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)

            Text(`完成：${this.studyGoal.finishedHours} / ${this.studyGoal.targetHours} 小时`)
              .fontSize(14)
              .fontColor('#DCE6FF')
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text(`${this.getGoalProgress()}%`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')

        Divider()
          .color('#88A2E8')
          .margin({ top: 18, bottom: 18 })

        Button('完成 1 小时学习')
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor('#3E64C5')
          .backgroundColor(Color.White)
          .borderRadius(12)
          .onClick(() => {
            this.addFinishedHour()
          })
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#3E64C5')
      .borderRadius(22)
      .margin({ bottom: 22 })
      //首页接收数据
      Row() {
        Column() {
          Text('来自首页的数据')
            .fontSize(12)
            .fontColor('#8A94A6')

          Text(`专注 ${this.receivedFocusMinutes}min · 完成 ${this.receivedCompletedCount}/${this.receivedTaskTotal} 项`)
            .fontSize(14)
            .fontColor('#4F7CFF')
            .fontWeight(FontWeight.Medium)
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#EEF2FF')
      .borderRadius(14)
      .margin({ bottom: 16 })


      // 学习任务标题和数组新增按钮
      Row() {
        Column() {
          Text('STUDY PLAN')
            .fontSize(14)
            .fontColor('#8A94A6')

          Text('学习任务')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111111')
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Button('+')
          .width(42)
          .height(42)
          .fontSize(24)
          .fontColor(Color.White)
          .backgroundColor('#4F7CFF')
          .borderRadius(21)
          .onClick(() => {
            this.addPlan()
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // List + ForEach + ListItem 显示 PlanItem 对象数组
      List({ space: 12 }) {
        ForEach(
          this.plans,
          (item: PlanItem, index: number) => {
            ListItem() {
              Row() {
                Text(`${index + 1}`)
                  .width(46)
                  .height(46)
                  .textAlign(TextAlign.Center)
                  .fontSize(18)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .backgroundColor(item.finished ? '#6CB45A' : '#4F7CFF')
                  .borderRadius(23)

                Column() {
                  Text(item.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(item.finished ? '#8A94A6' : '#111111')

                  Text(`${item.subject} · ${item.minutes}分钟`)
                    .fontSize(13)
                    .fontColor('#8A94A6')
                    .margin({ top: 5 })
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 14 })
                .layoutWeight(1)

                Text(item.finished ? '✓ 已完成' : '○ 未完成')
                  .fontSize(12)
                  .fontColor(item.finished ? '#4C8C2B' : '#666666')
                  .backgroundColor(item.finished ? '#DDF4C8' : '#ECECEC')
                  .padding({
                    left: 10,
                    right: 10,
                    top: 4,
                    bottom: 4
                  })
                  .borderRadius(10)
              }
              .width('100%')
              .padding(16)
              .backgroundColor(Color.White)
              .borderRadius(18)
            }
            .onClick(() => {
              this.togglePlan(index)
            })
          },
          (item: PlanItem) => item.title
        )
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Text('提示：点击任务可以切换“已完成 / 未完成”状态')
        .fontSize(12)
        .fontColor('#8A94A6')
        .margin({ top: 8 })

      // 底部导航
      Row() {
        Text('首页')
          .fontSize(16)
          .fontColor('#888888')
          .onClick(() => {
            router.back()
          })

        Text('任务')
          .fontSize(16)
          .fontColor('#4F7CFF')
          .fontWeight(FontWeight.Bold)

        Text('统计')
          .fontSize(16)
          .fontColor('#888888')

        Text('我的')
          .fontSize(16)
          .fontColor('#888888')
      }
      .width('100%')
      .padding({ top: 14, bottom: 14 })
      .justifyContent(FlexAlign.SpaceAround)
      .backgroundColor(Color.White)
      .borderRadius(18)
      .margin({ top: 12 })
    }
    .width('100%')
    .height('100%')
    .padding(20)
    .backgroundColor('#F5F7FB')
  }
}
