import { router } from '@kit.ArkUI'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'

interface TaskItem {
  code: string
  title: string
  subtitle: string
  status: string
}

interface StudyData{
  focusMinutes:number
  completedCount: number
  tasks: TaskItem[]
}

@Entry
@Component

struct Index {

  @State focusMinutes: number = 105

  @State completedCount: number = 2

  @State tasks: TaskItem[] = [
    {
      code: 'DS',
      title: '学习数据结构',
      subtitle: '数据结构 · 60分钟',
      status: '已完成'
    },
    {
      code: 'MA',
      title: '复习高等数学',
      subtitle: '高等数学 · 45分钟',
      status: '已完成'
    },
    {
      code: 'EN',
      title: '背诵英语单词',
      subtitle: '英语 · 30分钟',
      status: '未开始'
    },
    {
      code: 'AR',
      title: '学习 ArkTS',
      subtitle: '鸿蒙开发 · 40分钟',
      status: '未开始'
    }
  ]

  private getDataFilePath(): string {
    let context =
      this.getUIContext().getHostContext() as common.UIAbilityContext

    return context.filesDir + '/study_data.json'


  }

  private getProgress(): number {
    if (this.tasks.length === 0) {
      return 0
    }

    return Math.round(this.completedCount / this.tasks.length * 100)
  }

  // 修改数组中对应的任务对象状态
  private completeTask(index: number): void {
    let selectedTask: TaskItem = this.tasks[index]
    if (selectedTask.status === '已完成') {
      return
    }

    let updatedTasks: TaskItem[] = this.tasks.slice()
    updatedTasks[index] = {
      code: selectedTask.code,
      title: selectedTask.title,
      subtitle: selectedTask.subtitle,
      status: '已完成'
    }
    this.tasks = updatedTasks
    this.completedCount += 1
    this.focusMinutes += 10
  }

  // push 会改变 @State 数组，List 会自动显示新增的任务
  private addTask(): void {
    let newTask: TaskItem = {
      code: `SE${this.tasks.length + 1}`,
      title: '新学习任务',
      subtitle: '新学习任务 · 30分钟',
      status: '未开始'
    }
    this.tasks.push(newTask)
  }

  aboutToAppear(): void {
    this.loadData()
  }

  onPageShow(): void {
    // 每次首页重新显示：接收 TaskPage 产生的临时变化
    let extra =
      AppStorage.get<number>('extraFocusMinutes') ?? 0

    if (extra > 0) {
      this.focusMinutes += extra

      AppStorage.setOrCreate<number>(
        'extraFocusMinutes',
        0
      )
    }
  }

  onPageHide(): void {
    // 页面跳走、应用进入后台等时机保存
    this.saveData()
  }

  private saveData(): void {
    let file: fileIo.File | undefined = undefined

    try {
      // 1. 把当前内存里的数据组成一个对象
      let data: StudyData = {
        focusMinutes: this.focusMinutes,
        completedCount: this.completedCount,
        tasks: this.tasks
      }

      // 2. 对象转换成 JSON 字符串
      let jsonText: string = JSON.stringify(data)

      // 3. 找到文件路径
      let filePath: string = this.getDataFilePath()

      // 4. 打开文件
      file = fileIo.openSync(
        filePath,
        fileIo.OpenMode.WRITE_ONLY |
          fileIo.OpenMode.CREATE |
          fileIo.OpenMode.TRUNC
      )

      // 5. 写进去
      fileIo.writeSync(file.fd, jsonText)

      console.info('[StudyData] 保存成功：' + jsonText)
    } catch (error) {
      console.error('[StudyData] 保存失败')
    } finally {
      // 6. 用完一定关闭
      if (file !== undefined) {
        fileIo.closeSync(file)
      }
    }
  }

  private loadData(): void {
    try {
      let filePath: string = this.getDataFilePath()

      // 第一次运行时文件可能还不存在
      if (!fileIo.accessSync(filePath)) {
        console.info('[StudyData] 第一次启动，暂无存档文件')
        return
      }

      // 读取 JSON 文本
      let jsonText: string = fileIo.readTextSync(filePath)

      // JSON 字符串 → ArkTS 对象
      let data = JSON.parse(jsonText) as StudyData

      // 把读取到的数据恢复到 @State
      this.focusMinutes = data.focusMinutes
      this.completedCount = data.completedCount
      this.tasks = data.tasks

      console.info('[StudyData] 读取成功：' + jsonText)
    } catch (error) {
      console.error('[StudyData] 读取失败')
    }
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Column() {
          Text('学习助手')
            .fontSize(30)
            .fontWeight(FontWeight.Bold)
            .fontColor('#111111')

          Text('今天也要保持学习进度')
            .fontSize(14)
            .fontColor('#8A94A6')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('TODAY')
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

      // 今日进度卡片：简单变量和数组长度均直接绑定到界面
      Column() {
        Row() {
          Column() {
            Text('今日进度')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)

            Text(`已完成 ${this.completedCount} / ${this.tasks.length} 项任务`)
              .fontSize(14)
              .fontColor('#DCE6FF')
              .margin({ top: 8 })
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text(`${this.getProgress()}%`)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor(Color.White)
        }
        .width('100%')

        Divider()
          .color('#88A2E8')
          .margin({ top: 18, bottom: 18 })

        Row() {
          Column() {
            Text(`${this.tasks.length}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)

            Text('今日任务')
              .fontSize(13)
              .fontColor('#DCE6FF')
              .margin({ top: 5 })
          }

          Divider()
            .vertical(true)
            .height(42)
            .color('#88A2E8')

          Column() {
            Text(`${this.completedCount}`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)

            Text('已完成')
              .fontSize(13)
              .fontColor('#DCE6FF')
              .margin({ top: 5 })
          }

          Divider()
            .vertical(true)
            .height(42)
            .color('#88A2E8')

          Column() {
            Text(`${this.focusMinutes}min`)
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)

            Text('专注时间')
              .fontSize(13)
              .fontColor('#DCE6FF')
              .margin({ top: 5 })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#3E64C5')
      .borderRadius(22)
      .margin({ bottom: 22 })

      // 今日任务标题和数组新增按钮
      Row() {
        Column() {
          Text('TODAY TASKS')
            .fontSize(14)
            .fontColor('#8A94A6')

          Text('今日任务')
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
            this.addTask()
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      // List + ForEach + ListItem 显示 TaskItem 对象数组
      List({ space: 12 }) {
        ForEach(
          this.tasks,
          (item: TaskItem, index: number) => {
            ListItem() {
              Row() {
                Text(item.code)
                  .width(46)
                  .height(46)
                  .textAlign(TextAlign.Center)
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(item.status === '已完成' ? Color.White : '#4F7CFF')
                  .backgroundColor(item.status === '已完成' ? '#6CB45A' : '#EEF2FF')
                  .borderRadius(23)

                Column() {
                  Text(item.title)
                    .fontSize(18)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(item.status === '已完成' ? '#8A94A6' : '#111111')

                  Text(item.subtitle)
                    .fontSize(13)
                    .fontColor('#8A94A6')
                    .margin({ top: 5 })
                }
                .alignItems(HorizontalAlign.Start)
                .margin({ left: 14 })
                .layoutWeight(1)

                Text(item.status)
                  .fontSize(12)
                  .fontColor(item.status === '已完成' ? '#4C8C2B' : '#666666')
                  .backgroundColor(item.status === '已完成' ? '#DDF4C8' : '#ECECEC')
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
              this.completeTask(index)
            })
          },
          (item: TaskItem) => item.code
        )
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)

      Text('提示：点击未开始任务，可完成任务并增加 10 分钟专注时间')
        .fontSize(12)
        .fontColor('#8A94A6')
        .margin({ top: 8 })

      // 底部导航
      Row() {
        Text('首页')
          .fontSize(16)
          .fontColor('#4F7CFF')
          .fontWeight(FontWeight.Bold)

        Text('任务')
          .fontSize(16)
          .fontColor('#888888')
          .onClick(() => {
            router.pushUrl({
              url: 'pages/TaskPage',
              params: {
                focusMinutes: this.focusMinutes,
                completedCount: this.completedCount,
                taskTotal: this.tasks.length
              }
            })
          })

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
